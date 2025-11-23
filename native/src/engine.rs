use anyhow::{anyhow, Result};
use std::process::Stdio;
#[cfg(windows)]
use tokio::signal;
#[cfg(unix)]
use tokio::signal::unix::{signal, SignalKind};

use crate::strategies::base::{ExecutionContext, IsolationStrategy};

#[cfg(not(any(target_os = "linux", target_os = "windows", target_os = "macos")))]
use crate::strategies::host::HostStrategy;
#[cfg(target_os = "linux")]
use crate::strategies::linux::LinuxBwrapStrategy;
#[cfg(target_os = "macos")]
use crate::strategies::macos::MacOsSandboxStrategy;
#[cfg(target_os = "windows")]
use crate::strategies::windows::WindowsJobStrategy;

/// The core engine that drives the process execution.
/// It handles process spawning, IO pumping (piping stdout/stderr), and signal handling.
pub struct Engine {
    strategy: Box<dyn IsolationStrategy>,
}

impl Engine {
    /// Creates a new Engine instance with the appropriate isolation strategy for the current OS.
    pub fn new(sandbox: bool) -> Self {
        let strategy: Box<dyn IsolationStrategy> = if sandbox {
            #[cfg(target_os = "linux")]
            {
                Box::new(LinuxBwrapStrategy)
            }
            #[cfg(target_os = "windows")]
            {
                Box::new(WindowsJobStrategy)
            }
            #[cfg(target_os = "macos")]
            {
                Box::new(MacOsSandboxStrategy)
            }
            #[cfg(not(any(target_os = "linux", target_os = "windows", target_os = "macos")))]
            {
                Box::new(HostStrategy)
            }
        } else {
            // Fallback/Host strategy for non-sandboxed execution could be explicitly defined here.
            // For now, we assume cross-platform 'host' strategy logic is handled via std::process directly
            // or a specific HostStrategy implementation.
            Box::new(crate::strategies::host::HostStrategy)
        };
        Engine { strategy }
    }

    /// Executes the command defined in `ctx` and manages its lifecycle.
    ///
    /// This method ensures that:
    /// 1. STDOUT and STDERR are fully read until EOF.
    /// 2. The process is killed if a cancellation signal (Ctrl+C) is received.
    /// 3. No zombie processes remain (waiting for exit status).
    pub async fn run(&self, ctx: ExecutionContext) -> Result<i32> {
        let cmd_res = self.strategy.build_command(&ctx);
        if let Err(e) = cmd_res {
            return Err(e);
        }
        let cmd = cmd_res.unwrap();

        let mut child = tokio::process::Command::from(cmd)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .stdin(Stdio::null())
            .kill_on_drop(true) // Ensure child is killed if the engine panics/drops
            .spawn()
            .map_err(|e| anyhow!("Spawn failed: {}", e))?;

        let mut child_stdout = child.stdout.take().expect("No stdout");
        let mut child_stderr = child.stderr.take().expect("No stderr");

        // Task 1: Pump STDOUT to parent's stdout
        let stdout_task = tokio::spawn(async move {
            let mut stdout = tokio::io::stdout();
            let _ = tokio::io::copy(&mut child_stdout, &mut stdout).await;
        });

        // Task 2: Pump STDERR to parent's stderr
        let stderr_task = tokio::spawn(async move {
            let mut stderr = tokio::io::stderr();
            let _ = tokio::io::copy(&mut child_stderr, &mut stderr).await;
        });

        // Task 3: Watch for cancellation signals
        let kill_task = tokio::spawn(async move {
            wait_for_termination().await;
        });

        // Main Loop: Wait for process exit OR cancellation
        let exit_status = tokio::select! {
            status = child.wait() => status,
            _ = kill_task => {
                let _ = child.kill().await;
                // Return -1 to indicate cancellation
                return Ok(-1);
            }
        };

        // CRITICAL: Wait for IO tasks to finish flushing buffers before exiting.
        // This prevents race conditions where the process exits but data is still in the pipe.
        let _ = tokio::join!(stdout_task, stderr_task);

        match exit_status {
            Ok(s) => Ok(s.code().unwrap_or(-1)),
            Err(e) => Err(anyhow!("Wait failed: {}", e)),
        }
    }
}

/// Cross-platform signal listener for graceful shutdown.
async fn wait_for_termination() {
    #[cfg(unix)]
    {
        let mut sigterm = signal(SignalKind::terminate()).unwrap();
        let mut sigint = signal(SignalKind::interrupt()).unwrap();
        tokio::select! { _ = sigterm.recv() => {}, _ = sigint.recv() => {} };
    }
    #[cfg(windows)]
    {
        let _ = signal::ctrl_c().await;
    }
}
