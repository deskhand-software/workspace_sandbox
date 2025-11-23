# workspace_sandbox

[![pub package](https://img.shields.io/pub/v/workspace_sandbox.svg)](https://pub.dev/packages/workspace_sandbox)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A cross-platform workspace abstraction for running shell commands in isolated directories with native sandboxing, network control, and real-time process streaming.

Designed for **AI agents**, **automation tools**, and **build systems** that need to execute arbitrary commands with strong isolation guarantees and file system observability.

---

## Features

- **Isolated workspaces** – Ephemeral or persistent directory roots with automatic cleanup
- **Native sandboxing** – Job Objects (Windows), Bubblewrap (Linux), Seatbelt (macOS)
- **Network control** – Block or allow network access per workspace
- **Streaming output** – Real-time stdout/stderr via Dart streams
- **Reactive events** – Monitor process lifecycle and output via `onEvent` stream
- **Timeout & cancellation** – Automatic process termination with configurable timeouts
- **File system helpers** – Tree visualization, recursive grep, glob search, binary I/O
- **Simple API** – Write commands as you would in a terminal, no complex process management

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  workspace_sandbox: ^0.1.3
```

Then run:

```bash
dart pub get
```

---

## Quick Start

### Basic Usage

```dart
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  final ws = Workspace.ephemeral();
  
  await ws.writeFile('script.sh', 'echo "Hello World"');
  
  final result = await ws.run('sh script.sh');
  print(result.stdout); // Hello World
  
  await ws.dispose();
}
```

### With Network Isolation

```dart
final ws = Workspace.ephemeral(
  options: const WorkspaceOptions(
    sandbox: true,
    allowNetwork: false, // Block all network access
  ),
);

// This will fail with network unreachable
await ws.run('ping google.com');
```

### Streaming Long-Running Processes

```dart
final ws = Workspace.ephemeral();

final process = await ws.start('npm install');

process.stdout.listen((line) => print('[NPM] $line'));
process.stderr.listen((line) => print('[ERR] $line'));

final exitCode = await process.exitCode;
print('Installation complete: $exitCode');

await ws.dispose();
```

### Reactive Event Monitoring

```dart
final ws = Workspace.ephemeral();

// Listen to all workspace events
ws.onEvent.listen((event) {
  if (event is ProcessLifecycleEvent) {
    print('Process ${event.pid}: ${event.state}');
  } else if (event is ProcessOutputEvent) {
    print('[${event.isError ? "ERR" : "OUT"}] ${event.content}');
  }
});

await ws.run('echo "Hello"');
await ws.dispose();
```

---

## API Reference

### Workspace

Primary interface for creating and managing isolated execution environments.

#### Constructors

**`Workspace.ephemeral({ String? id, WorkspaceOptions? options })`**

Creates an ephemeral workspace in the system temp directory with sandboxing enabled by default. Automatically deleted on `dispose()`.

**`Workspace.at(String path, { String? id, WorkspaceOptions? options })`**

Uses an existing directory as the workspace root. Files persist after `dispose()`. Sandboxing is optional.

#### Core Methods

**`Future<CommandResult> run(String commandLine, { WorkspaceOptions? options })`**

Execute a command to completion. Returns buffered stdout/stderr and exit code.

```dart
final result = await ws.run('python script.py');
if (result.isSuccess) {
  print(result.stdout);
}
```

**`Future<WorkspaceProcess> start(String commandLine, { WorkspaceOptions? options })`**

Start a long-running process with streaming output.

```dart
final proc = await ws.start('tail -f log.txt');
proc.stdout.listen(print);
```

**`Future<CommandResult> exec(String executable, List<String> args, { WorkspaceOptions? options })`**

Execute a binary directly with explicit arguments (bypasses shell).

**`Future<WorkspaceProcess> spawn(String executable, List<String> args, { WorkspaceOptions? options })`**

Spawn a binary as a background process with explicit arguments.

#### File Operations

All paths are relative to workspace root.

- `Future<File> writeFile(String path, String content)`
- `Future<String> readFile(String path)`
- `Future<File> writeBytes(String path, List<int> bytes)`
- `Future<List<int>> readBytes(String path)`
- `Future<bool> exists(String path)`
- `Future<Directory> createDir(String path)`
- `Future<void> delete(String path)`
- `Future<void> copy(String source, String dest)`
- `Future<void> move(String source, String dest)`

#### Observability Helpers

**`Future<String> tree({ int maxDepth = 5 })`**

Generate a visual directory tree.

```dart
final tree = await ws.tree();
print(tree);
// workspace_root
// ├── src
// │   └── main.dart
// └── README.md
```

**`Future<String> grep(String pattern, { bool recursive = true })`**

Search for text patterns in files.

```dart
final results = await ws.grep('TODO');
// src/utils.dart:42: // TODO: implement
```

**`Future<List<String>> find(String pattern)`**

Find files matching a glob pattern.

```dart
final dartFiles = await ws.find('*.dart');
// ['src/main.dart', 'lib/utils.dart']
```

#### Event Stream

**`Stream<WorkspaceEvent> onEvent`**

Unified stream of all events happening in the workspace.

```dart
ws.onEvent.listen((event) {
  if (event is ProcessLifecycleEvent) {
    print('${event.command} -> ${event.state}');
  } else if (event is ProcessOutputEvent) {
    print('[${event.pid}] ${event.content}');
  }
});
```

---

### WorkspaceOptions

Configuration for command execution behavior.

```dart
const WorkspaceOptions({
  Duration? timeout,
  Map<String, String>? env,
  bool includeParentEnv = true,
  String? workingDirectoryOverride,
  bool sandbox = false,
  bool allowNetwork = true,
})
```

**Fields:**

- **`timeout`** – Kill process after duration
- **`env`** – Additional environment variables
- **`includeParentEnv`** – Inherit parent process environment
- **`workingDirectoryOverride`** – Custom working directory
- **`sandbox`** – Enable native OS sandboxing
- **`allowNetwork`** – Allow network access (requires `sandbox: true` for enforcement)

**Example:**

```dart
final result = await ws.run(
  'python train.py',
  options: const WorkspaceOptions(
    timeout: Duration(hours: 2),
    env: {'CUDA_VISIBLE_DEVICES': '0'},
    sandbox: true,
    allowNetwork: false,
  ),
);
```

---

### CommandResult

Result of a completed command.

**Fields:**

- `int exitCode`
- `String stdout`
- `String stderr`
- `Duration duration`
- `bool isCancelled`

**Getters:**

- `bool isSuccess` – Returns `exitCode == 0`
- `bool isFailure` – Returns `exitCode != 0`

---

### WorkspaceProcess

Handle to a running process.

**Streams:**

- `Stream<String> stdout`
- `Stream<String> stderr`

**Future:**

- `Future<int> exitCode`

**Methods:**

- `void kill()` – Terminate process immediately

---

### Events

**`WorkspaceEvent`** (sealed base class)
- `DateTime timestamp`
- `String workspaceId`

**`ProcessLifecycleEvent extends WorkspaceEvent`**
- `int pid`
- `String command`
- `ProcessState state` (started, stopped, failed)
- `int? exitCode`

**`ProcessOutputEvent extends WorkspaceEvent`**
- `int pid`
- `String command`
- `String content`
- `bool isError` (true = stderr, false = stdout)

---

## Security & Sandboxing

### Isolation Mechanisms

**Windows (x64)**

Processes run in a **Job Object** with:
- Process group isolation
- Automatic child process termination
- Network blocking via environment proxy settings

**Linux (x64)**

Processes run under **Bubblewrap** with:
- Root passthrough strategy (host mounted read-only at `/`)
- Workspace mounted read-write
- Tool caches exposed (`.m2`, `.gradle`, `.cargo`, `.pub-cache`)
- Network namespace isolation (`--unshare-net` when `allowNetwork: false`)

**macOS (x64 / ARM64)**

Processes run under **Seatbelt** (sandbox-exec) with:
- Read-only host filesystem
- Write access to workspace and temp directories
- Tool cache allowlisting
- Network policy enforcement

### Network Control

Set `allowNetwork: false` to block all network access:

```dart
final ws = Workspace.ephemeral(
  options: const WorkspaceOptions(
    sandbox: true,
    allowNetwork: false,
  ),
);

// Blocked at OS level
await ws.run('curl https://example.com'); // Fails
```

### Best Practices

1. Always enable sandboxing for untrusted code
2. Use `allowNetwork: false` unless network is explicitly required
3. Set aggressive timeouts for AI-generated commands
4. Validate command strings before execution
5. Use `Workspace.ephemeral()` for ephemeral, isolated environments

---

## Platform Support

| Platform | Architecture | Sandboxing | Network Isolation |
|----------|-------------|------------|-------------------|
| Windows  | x64         | Job Objects | ENV proxy blocking |
| Linux    | x64         | Bubblewrap (bwrap) | Kernel-level (`--unshare-net`) |
| macOS    | x64 / ARM64 | Seatbelt (sandbox-exec) | Process-level blocking |

---

## Requirements

### Linux

**Bubblewrap** must be installed for sandboxing:

```bash
# Ubuntu/Debian
sudo apt install bubblewrap

# Fedora/RHEL
sudo dnf install bubblewrap

# Arch
sudo pacman -S bubblewrap
```

### Windows

No additional dependencies. Job Objects are built into Windows.

### macOS

No additional dependencies. Seatbelt (sandbox-exec) is built into macOS.

---

## Examples

See the `example/` directory for comprehensive usage demonstrations:

- `example.dart` – Quick-start basic usage
- `01_advanced_python_api.dart` – HTTP server with streaming logs
- `02_security_audit.dart` – Network isolation validation
- `03_git_workflow_at.dart` – Persistent workspace git operations
- `04_data_processing_spawn.dart` – Long-running background processes
- `05_interactive_repl.dart` – Real-time stdin/stdout interaction

Run any example:

```bash
dart run example/example.dart
```

---

## Building Native Binaries

The native launcher is written in Rust. Rebuild for all platforms:

### Prerequisites

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Linux

```bash
cd native
cargo build --release
cp target/release/workspace_launcher ../bin/linux/x64/
```

### Windows

```powershell
cd native
cargo build --release
Copy-Item target\release\workspace_launcher.exe ..\bin\windows\x64\
```

### macOS

```bash
cd native
cargo build --release
cp target/release/workspace_launcher ../bin/macos/x64/
```

### Cross-Compilation

```bash
# For Windows from Linux
rustup target add x86_64-pc-windows-gnu
cargo build --release --target x86_64-pc-windows-gnu

# For macOS from Linux (requires osxcross)
rustup target add x86_64-apple-darwin
cargo build --release --target x86_64-apple-darwin
```

---

## Contributing

Contributions are welcome. Before submitting:

```bash
dart format lib test example
dart analyze
dart test
```

Ensure native library builds successfully on target platforms.

**Issues & PRs:** [GitHub Repository](https://github.com/deskhand-software/workspace_sandbox)

---

## License

Apache-2.0 License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

- Built with Rust for cross-platform native execution
- Sandboxing: Windows Job Objects, Linux Bubblewrap, macOS Seatbelt
- Designed for AI agent safety and build automation

---

## Links

- **Documentation:** [pub.dev/packages/workspace_sandbox](https://pub.dev/packages/workspace_sandbox)
- **Issues:** [GitHub Issues](https://github.com/deskhand-software/workspace_sandbox/issues)
- **Organization:** [DeskHand Software](https://deskhand.dev)
