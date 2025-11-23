use std::process::{Command, Stdio};
use anyhow::Result;
use which::which;
use super::base::{IsolationStrategy, ExecutionContext};

use windows::Win32::System::JobObjects::{
    CreateJobObjectW, AssignProcessToJobObject, SetInformationJobObject,
    JobObjectExtendedLimitInformation, JOBOBJECT_EXTENDED_LIMIT_INFORMATION,
    JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE,
};
use windows::Win32::System::Threading::GetCurrentProcess;

pub struct WindowsJobStrategy;

impl IsolationStrategy for WindowsJobStrategy {
    fn name(&self) -> &str { "Windows Job Object" }

    fn build_command(&self, ctx: &ExecutionContext) -> Result<Command> {
        let mut program = ctx.cmd.clone();
        let mut args = ctx.args.clone();
        let prog_lower = program.to_lowercase();

        let builtins = ["echo", "dir", "del", "copy", "move", "mkdir", "rmdir", "type", "cls", "ping", "npm", "node", "ver"];
        let is_batch = prog_lower.ends_with(".bat") || prog_lower.ends_with(".cmd");

        if builtins.contains(&prog_lower.as_str()) || is_batch {
            args.insert(0, "/c".to_string());
            args.insert(1, program.clone());
            program = "cmd".to_string();
        }

        let resolved_program = if program == "cmd" {
            "cmd".into()
        } else {
            which(&program).unwrap_or_else(|_| program.clone().into())
        };
        
        let mut command = Command::new(resolved_program);
        command.args(&args)
               .envs(&ctx.env_vars)
               .stdin(Stdio::null())
               .stdout(Stdio::piped())
               .stderr(Stdio::piped());

        // --- NETWORK BLOCK (Proxy Trick) ---
        if !ctx.allow_network {
            // Windows Job Objects do not isolate network.
            // We enforce a dead proxy to prevent accidental network access by tools like curl/npm/pip.
            command.env("HTTP_PROXY", "http://127.0.0.1:0");
            command.env("HTTPS_PROXY", "http://127.0.0.1:0");
            command.env("ALL_PROXY", "http://127.0.0.1:0");
            command.env("NO_PROXY", ""); // Force proxy usage
        }

        if let Some(cwd) = &ctx.cwd {
            command.current_dir(cwd);
        } else {
            command.current_dir(&ctx.root_path);
        }

        unsafe {
            let job = CreateJobObjectW(None, None)?;
            let mut info = JOBOBJECT_EXTENDED_LIMIT_INFORMATION::default();
            info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            SetInformationJobObject(job, JobObjectExtendedLimitInformation, &info as *const _ as *const _, std::mem::size_of::<JOBOBJECT_EXTENDED_LIMIT_INFORMATION>() as u32)?;
            AssignProcessToJobObject(job, GetCurrentProcess())?;
        }

        Ok(command)
    }
}
