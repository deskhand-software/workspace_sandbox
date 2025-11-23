use super::base::{ExecutionContext, IsolationStrategy};
use anyhow::Result;
use std::path::Path;
use std::process::{Command, Stdio};

pub struct MacOsSandboxStrategy;

impl IsolationStrategy for MacOsSandboxStrategy {
    fn name(&self) -> &str {
        "MacOS Sandbox (Seatbelt)"
    }

    fn build_command(&self, ctx: &ExecutionContext) -> Result<Command> {
        let sandbox_exec = "/usr/bin/sandbox-exec";

        if !Path::new(sandbox_exec).exists() {
            return Err(anyhow::anyhow!(
                "sandbox-exec not found at {}",
                sandbox_exec
            ));
        }

        let mut command = Command::new(sandbox_exec);

        // Basic permissive profile.
        // In the future, this can be tightened to 'deny default' with specific allows.
        let mut profile = String::from("(version 1) (allow default)");

        if !ctx.allow_network {
            profile.push_str(" (deny network*)");
            profile.push_str(" (allow network* (local ip \"localhost:*\"))");
        }

        command.arg("-p").arg(profile);
        command.arg(&ctx.cmd).args(&ctx.args);
        command.env_clear();
        command.envs(&ctx.env_vars);

        if let Some(cwd) = &ctx.cwd {
            command.current_dir(cwd);
        } else {
            command.current_dir(&ctx.root_path);
        }

        command
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());

        Ok(command)
    }
}
