use std::process::ExitStatus;
use std::process::Stdio;
use anyhow::{Result, anyhow};
use tokio::io::{AsyncReadExt, AsyncWriteExt}; // Necesario para copiar
#[cfg(unix)]
use tokio::signal::unix::{signal, SignalKind};
#[cfg(windows)]
use tokio::signal;

use crate::strategies::{
    base::{ExecutionContext, IsolationStrategy},
    host::HostStrategy,
};

#[cfg(target_os = "linux")]
use crate::strategies::linux::LinuxBwrapStrategy;
#[cfg(target_os = "windows")]
use crate::strategies::windows::WindowsJobStrategy;
#[cfg(target_os = "macos")]
use crate::strategies::macos::MacOsSandboxStrategy;

pub struct Engine {
    strategy: Box<dyn IsolationStrategy>,
}

impl Engine {
    pub fn new(sandbox: bool) -> Self {
        let strategy: Box<dyn IsolationStrategy> = if sandbox {
            #[cfg(target_os = "linux")]
            { Box::new(LinuxBwrapStrategy) }
            #[cfg(target_os = "windows")]
            { Box::new(WindowsJobStrategy) }
            #[cfg(target_os = "macos")]
            { Box::new(MacOsSandboxStrategy) }
            #[cfg(not(any(target_os = "linux", target_os = "windows", target_os = "macos")))]
            { Box::new(HostStrategy) }
        } else {
            Box::new(HostStrategy)
        };
        Engine { strategy }
    }

    pub async fn run(&self, ctx: ExecutionContext) -> Result<i32> {
        eprintln!("[Launcher] Using strategy: {}", self.strategy.name());
        eprintln!("[Launcher] Command: {} {:?}", ctx.cmd, ctx.args);
        
        let cmd = self.strategy.build_command(&ctx)?;
        
        // IMPORTANTE: Aseguramos que la estrategia haya configurado Piped
        let mut child = tokio::process::Command::from(cmd)
            .stdout(Stdio::piped()) // Forzamos Piped aquí por seguridad
            .stderr(Stdio::piped())
            .stdin(Stdio::null())
            .spawn()
            .map_err(|e| anyhow!("Spawn failed via {}: {}", self.strategy.name(), e))?;

        eprintln!("[Launcher] Process started with PID: {:?}", child.id());

        // Tomar control de los handles del hijo
        let mut child_stdout = child.stdout.take().expect("Failed to capture stdout");
        let mut child_stderr = child.stderr.take().expect("Failed to capture stderr");

        // Tareas de copiado asíncrono (Bridge)
        // Copiamos stdout del hijo -> stdout del padre (Rust) -> Dart lee esto
        let stdout_task = tokio::spawn(async move {
            let mut stdout = tokio::io::stdout();
            if let Err(e) = tokio::io::copy(&mut child_stdout, &mut stdout).await {
                eprintln!("[Launcher] Error copying stdout: {}", e);
            }
        });

        // Copiamos stderr del hijo -> stderr del padre (Rust) -> Dart lee esto
        // OJO: Si queremos que los logs del launcher no se mezclen con los del hijo,
        // podríamos prefijarlos, pero por ahora raw copy es mejor.
        let stderr_task = tokio::spawn(async move {
            let mut stderr = tokio::io::stderr();
            if let Err(e) = tokio::io::copy(&mut child_stderr, &mut stderr).await {
                eprintln!("[Launcher] Error copying stderr: {}", e);
            }
        });

        // Esperar a que el proceso termine Y a que se vacíen los pipes
        tokio::select! {
            status_res = child.wait() => {
                // Esperar que terminen de copiar I/O antes de salir
                let _ = tokio::join!(stdout_task, stderr_task);
                
                let s: ExitStatus = status_res?;
                let code = s.code().unwrap_or(-1);
                eprintln!("[Launcher] Process exited with code: {}", code);
                
                #[cfg(unix)]
                if let Some(sig) = s.signal() {
                    eprintln!("[Launcher] Process killed by signal: {}", sig);
                    return Ok(-1);
                }
                Ok(code)
            }
            _ = wait_for_termination() => {
                eprintln!("[Launcher] Received termination signal, killing child...");
                let _ = child.kill().await;
                Ok(-1)
            }
        }
    }
}

async fn wait_for_termination() {
    #[cfg(unix)]
    {
        let mut sigterm = signal(SignalKind::terminate()).unwrap();
        let mut sigint = signal(SignalKind::interrupt()).unwrap();
        tokio::select! { _ = sigterm.recv() => {}, _ = sigint.recv() => {} };
    }
    #[cfg(windows)]
    { let _ = signal::ctrl_c().await; }
}
