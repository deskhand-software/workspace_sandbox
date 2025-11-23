use anyhow::Result;
use std::collections::HashMap;
use std::process::Command;

/// Context provided to the isolation strategy to build the command.
pub struct ExecutionContext {
    /// Unique identifier for this process execution (useful for logging/debugging).
    #[allow(dead_code)] // Kept for future observability features
    pub id: String,

    /// The absolute path to the workspace root.
    pub root_path: String,

    /// The binary or command to execute.
    pub cmd: String,

    /// Arguments for the command.
    pub args: Vec<String>,

    /// Environment variables to inject into the process.
    pub env_vars: HashMap<String, String>,

    /// Working directory override (optional).
    pub cwd: Option<String>,

    /// Whether to allow network access in the sandbox.
    pub allow_network: bool,
}

/// Trait that every platform-specific isolation strategy must implement.
pub trait IsolationStrategy {
    /// Builds a `std::process::Command` configured with the specific sandbox parameters
    /// (namespaces, job objects, profiles, etc.).
    fn build_command(&self, ctx: &ExecutionContext) -> Result<Command>;

    /// Returns the display name of the strategy (e.g., "Linux Bubblewrap").
    #[allow(dead_code)] // Used for internal logging/debugging
    fn name(&self) -> &str;
}
