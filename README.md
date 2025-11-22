# workspace_sandbox

[![pub package](https://img.shields.io/pub/v/workspace_sandbox.svg)](https://pub.dev/packages/workspace_sandbox)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

A cross-platform workspace abstraction for running shell commands in isolated directories with native sandboxing, network control, and real-time process streaming.

Designed for **AI agents**, **automation tools**, and **build systems** that need to execute arbitrary commands with strong isolation guarantees and file system observability.

---

## Features

- **Isolated workspaces** – Ephemeral or persistent directory roots with automatic cleanup
- **Native sandboxing** – AppContainer (Windows) and Bubblewrap (Linux) for OS-level isolation
- **Network control** – Block or allow network access per workspace
- **Streaming output** – Real-time stdout/stderr via Dart streams
- **Timeout & cancellation** – Automatic process termination with configurable timeouts
- **File system helpers** – Tree visualization, recursive grep, glob search, binary I/O
- **Simple API** – Write commands as you would in a terminal, no complex process management

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  workspace_sandbox: ^0.1.1
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
  final ws = Workspace.secure();
  
  await ws.writeFile('script.sh', 'echo "Hello World"');
  
  final result = await ws.run('sh script.sh');
  print(result.stdout); // Hello World
  
  await ws.dispose();
}
```

### With Network Isolation

```dart
final ws = Workspace.secure(
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
final ws = Workspace.secure();

final process = await ws.start('npm install');

process.stdout.listen((line) => print('[NPM] $line'));
process.stderr.listen((line) => print('[ERR] $line'));

final exitCode = await process.exitCode;
print('Installation complete: $exitCode');

await ws.dispose();
```

---

## API Reference

### Workspace

Primary interface for creating and managing isolated execution environments.

#### Constructors

**`Workspace.secure({ String? id, WorkspaceOptions? options })`**

Creates an ephemeral workspace in the system temp directory with sandboxing enabled by default. Automatically deleted on `dispose()`.

**`Workspace.host(String path, { String? id, WorkspaceOptions? options })`**

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

#### File Operations

All paths are relative to workspace root.

- `Future<void> writeFile(String path, String content)`
- `Future<String> readFile(String path)`
- `Future<void> writeBytes(String path, List<int> bytes)`
- `Future<List<int>> readBytes(String path)`
- `Future<bool> exists(String path)`
- `Future<void> createDir(String path)`
- `Future<void> delete(String path)`
- `Future<void> copy(String source, String dest)`
- `Future<void> move(String source, String dest)`

#### Observability Helpers

**`Future<String> tree({ int maxDepth = 10 })`**

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
  bool allowNetwork = true, // New in v0.1.1
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

## Security & Sandboxing

### Isolation Mechanisms

**Windows (x64)**

Processes run in an **AppContainer** with:
- Restricted filesystem access
- No network access by default (unless `allowNetwork: true`)
- Isolated from parent process privileges

**Linux (x64)**

Processes run under **Bubblewrap** with:
- Empty root strategy (`--tmpfs /`)
- Read-only system mounts (`/usr`, `/bin`, `/lib`)
- Network namespace isolation (`--unshare-net` when `allowNetwork: false`)
- Workspace root bind-mounted to `/app`

### Network Control

Set `allowNetwork: false` to block all network access:

```dart
final ws = Workspace.secure(
  options: const WorkspaceOptions(
    sandbox: true,
    allowNetwork: false,
  ),
);

// Blocked at kernel level (Linux) or capability level (Windows)
await ws.run('curl https://example.com'); // Fails
```

**Additional Security Layer:**

`SecurityGuard` statically analyzes commands before execution to block:
- Network binaries (curl, wget, ssh, nc)
- PowerShell network calls (`Net.Sockets`, `WebRequest`)
- Python network usage (`socket`, `urllib`, `http.client`)
- Node.js network modules (`require('net')`, `require('http')`)

### Best Practices

1. Always enable sandboxing for untrusted code
2. Use `allowNetwork: false` unless network is explicitly required
3. Set aggressive timeouts for AI-generated commands
4. Validate command strings before execution
5. Use `Workspace.secure()` for ephemeral, isolated environments

---

## Platform Support

| Platform | Architecture | Sandboxing | Network Isolation |
|----------|-------------|------------|-------------------|
| Windows  | x64         | AppContainer | Heuristic blocking |
| Linux    | x64         | Bubblewrap | Kernel-level (`--unshare-net`) |
| macOS    | –           | Not supported | – |

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

**Node.js/NPM** (if using in examples):

```bash
sudo apt install nodejs npm
```

### Windows

No additional dependencies. AppContainer is part of Windows 8+.

---

## Examples

See the `example/` directory for comprehensive usage demonstrations:

- `01_basic_usage.dart` – Core workspace lifecycle
- `02_observability.dart` – File system inspection (tree, grep, find)
- `03_network_isolation.dart` – Network blocking and allowing
- `04_streaming_output.dart` – Real-time process output handling
- `05_timeout_control.dart` – Timeout and cancellation
- `06_host_vs_secure.dart` – Persistent vs ephemeral workspaces

Run any example:

```bash
dart run example/01_basic_usage.dart
```

---

## Building Native Library

If modifying the C++ core, rebuild the native library:

### Linux

```bash
cd native
mkdir -p build-linux && cd build-linux
cmake ..
cmake --build . --config Release
cp libworkspace_core.so ../bin/linux/x64/
cd ../..
```

### Windows

```powershell
cd native
New-Item -ItemType Directory -Path build-windows -Force
cd build-windows
cmake .. -A x64
cmake --build . --config Release
Copy-Item .\Release\workspace_core.dll ..\bin\windows\x64\
cd ..\..
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

- Built with [dart:ffi](https://dart.dev/guides/libraries/c-interop)
- Sandboxing: Windows AppContainer & Linux Bubblewrap
- Designed for AI agent safety and build automation

---

## Links

- **Documentation:** [pub.dev/packages/workspace_sandbox](https://pub.dev/packages/workspace_sandbox)
- **Issues:** [GitHub Issues](https://github.com/deskhand-software/workspace_sandbox/issues)
- **Organization:** [DeskHand Software](https://deskhand.dev)