use super::base::{ExecutionContext, IsolationStrategy};
use anyhow::{Context, Result};
use std::path::Path;
use std::process::{Command, Stdio};
use which::which;

pub struct LinuxBwrapStrategy;

impl IsolationStrategy for LinuxBwrapStrategy {
    fn name(&self) -> &str {
        "Linux Bubblewrap"
    }

    fn build_command(&self, ctx: &ExecutionContext) -> Result<Command> {
        let bwrap_path = which("bwrap").context("bwrap not found")?;
        let mut command = Command::new(bwrap_path);

        // --- Base Isolation ---
        command
            .arg("--unshare-all")
            .arg("--new-session")
            .arg("--die-with-parent");

        // --- Filesystem Construction (Usr Merge Compatibility) ---
        // Instead of binding /bin or /lib directly, we bind /usr and symlink them.
        // This is robust for modern distros (Fedora, Debian, Ubuntu/WSL).
        command
            .arg("--tmpfs")
            .arg("/")
            .arg("--ro-bind")
            .arg("/usr")
            .arg("/usr")
            .arg("--symlink")
            .arg("usr/lib")
            .arg("/lib")
            .arg("--symlink")
            .arg("usr/lib64")
            .arg("/lib64")
            .arg("--symlink")
            .arg("usr/bin")
            .arg("/bin")
            .arg("--symlink")
            .arg("usr/sbin")
            .arg("/sbin")
            .arg("--proc")
            .arg("/proc")
            .arg("--dev")
            .arg("/dev")
            .arg("--tmpfs")
            .arg("/tmp");

        // --- System Configuration (Selective Bind) ---
        // We purposefully avoid mounting the entire /etc directory to prevent
        // conflicts with broken symlinks (common in WSL for resolv.conf).
        let etc_binds = [
            "/etc/resolv.conf",
            "/etc/hosts",
            "/etc/ssl/certs",
            "/etc/alternatives",
            "/etc/environment",
            "/etc/passwd",
            "/etc/group",
            "/etc/nsswitch.conf",
            "/etc/localtime",
        ];

        for path in &etc_binds {
            // Check if file exists on host before trying to bind
            if Path::new(path).exists() {
                // If it's a symlink (like resolv.conf often is), resolving it ensures
                // we bind the actual target file, bypassing broken link issues.
                if let Ok(real_path) = std::fs::canonicalize(path) {
                    command.arg("--ro-bind").arg(real_path).arg(path);
                } else {
                    command.arg("--ro-bind").arg(path).arg(path);
                }
            }
        }

        // --- Dev Tools & Libraries ---
        for dir in ["/opt", "/snap", "/usr/local"] {
            if Path::new(dir).exists() {
                command.arg("--ro-bind").arg(dir).arg(dir);
            }
        }

        // --- Network ---
        if ctx.allow_network {
            command.arg("--share-net");
        } else {
            command.arg("--unshare-net");
        }

        // --- Workspace & CWD ---
        command.arg("--bind").arg(&ctx.root_path).arg("/app");
        command.arg("--chdir").arg("/app");

        // --- Environment ---
        command.env_clear();
        // Pass-through host environment variables for maximum compatibility
        for (key, value) in std::env::vars() {
            command.arg("--setenv").arg(&key).arg(&value);
        }
        // Overrides
        command.arg("--setenv").arg("HOME").arg("/tmp");
        command.arg("--setenv").arg("TERM").arg("xterm-256color");

        // Inject user-defined variables
        for (key, val) in &ctx.env_vars {
            command.arg("--setenv").arg(key).arg(val);
        }

        // --- Capabilities ---
        command.arg("--cap-drop").arg("ALL");

        // --- User Command ---
        command.arg("--").arg(&ctx.cmd).args(&ctx.args);

        command
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        Ok(command)
    }
}
