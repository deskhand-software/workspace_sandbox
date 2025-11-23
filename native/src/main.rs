mod engine;
mod strategies;

use crate::engine::Engine;
use crate::strategies::base::ExecutionContext;
use clap::Parser;
use std::process;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(long)]
    id: String,
    #[arg(long)]
    workspace: String,
    #[arg(long)]
    sandbox: bool,
    #[arg(long)]
    no_net: bool,
    #[arg(long)]
    cwd: Option<String>,
    #[arg(long, value_parser = parse_key_val)]
    env: Vec<(String, String)>,
    #[arg(last = true)]
    command: Vec<String>,
}

fn parse_key_val(s: &str) -> Result<(String, String), String> {
    let pos = s
        .find('=')
        .ok_or_else(|| format!("invalid KEY=value: no `=` found in `{}`", s))?;
    Ok((s[..pos].to_string(), s[pos + 1..].to_string()))
}

#[tokio::main]
async fn main() {
    let args = Args::parse();

    if args.command.is_empty() {
        eprintln!("[Launcher] ERROR: No command provided");
        process::exit(98);
    }

    let ctx = ExecutionContext {
        id: args.id,
        root_path: args.workspace,
        cmd: args.command[0].clone(),
        args: args.command[1..].to_vec(),
        env_vars: args.env.into_iter().collect(),
        cwd: args.cwd,
        allow_network: !args.no_net,
    };

    let engine = Engine::new(args.sandbox);

    match engine.run(ctx).await {
        Ok(code) => process::exit(code),
        Err(e) => {
            eprintln!("[Launcher] FATAL ERROR: {:#}", e);
            process::exit(99);
        }
    }
}
