# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.1] - 2025-11-22

### Added

**FileSystem Observability Helpers**
- `tree(maxDepth)`: Generate visual directory tree for LLM context windows
- `grep(pattern, recursive)`: Recursive text search with file:line output
- `find(pattern)`: Glob-style file pattern matching
- `readBytes()` / `writeBytes()`: Binary file I/O support
- `copy(source, dest)` / `move(source, dest)`: File management utilities

**Network Isolation Control**
- New `allowNetwork` flag in `WorkspaceOptions` (defaults to `true`)
- Linux: Native kernel-level network blocking via `--unshare-net` (Bubblewrap)
- Windows: Heuristic-based `SecurityGuard` blocks known network binaries (curl, wget, ssh, npm) before execution
- Detects and blocks Python socket usage and PowerShell network calls

**Enhanced Timeout & Cancellation**
- `isCancelled` flag in `CommandResult` reliably indicates timeout-triggered termination
- Improved native process cleanup on timeout (SIGKILL on Linux, TerminateProcess on Windows)
- Timeout now properly propagates cancellation state regardless of OS exit code quirks

**Expanded Examples**
- `01_basic_usage.dart`: Core workspace lifecycle demonstration
- `02_observability.dart`: File system inspection utilities showcase
- `03_network_isolation.dart`: Network blocking and allowing examples
- `04_streaming_output.dart`: Real-time process output handling
- `05_timeout_control.dart`: Timeout mechanism validation
- `06_host_vs_secure.dart`: Persistent vs ephemeral workspace comparison

### Changed

**Linux Sandboxing Improvements**
- Migrated to "Empty Root" strategy (`--tmpfs /`) for maximum isolation
- Added `/usr/local` mount for user-installed binaries (npm, node)
- Improved support for Merged-USR distributions (Fedora, Arch, modern Ubuntu)
- Added standard symlinks (`/bin` -> `/usr/bin`, `/lib` -> `/usr/lib`)

**API Refinements**
- `CommandResult` now exposes `isSuccess` and `isFailure` convenience getters
- Internal `command_line` variables renamed to `commandLine` for Dart convention compliance
- Improved error messages with platform-specific language support (Spanish Windows errors)

### Fixed

- Windows: Resolved native library linker errors and C++ signature mismatches
- Linux: Fixed NPM/Node.js detection in sandboxed environments (WSL2 compatibility)
- Cross-platform: `ShellParser` now handles case-insensitive command detection (e.g., `CuRl`, `PoWeRsHeLl`)
- Timeout mechanism now correctly reports cancellation state across all platforms
- Whitespace handling in shell command parsing (quotes, pipes, redirects)

### Security

- Enhanced static analysis in `SecurityGuard` for obfuscated network commands
- Improved detection of inline scripting language network usage (Python `urllib`, Node.js `require('net')`)
- Added comprehensive penetration testing suite (`pentest_test.dart`) validating:
  - Path traversal protection (Dart API and OS-level)
  - Symlink attack resistance (Linux)
  - Network exfiltration prevention (socket-level)
  - Resource exhaustion handling (fork bomb simulation)

---

## [0.1.0] - 2025-11-21

### Added

**Core Workspace API**
- `Workspace.secure()`: Creates ephemeral temporary workspaces with automatic cleanup and native sandboxing
- `Workspace.host(path)`: Uses existing directories as workspace roots
- `run()`: Execute commands to completion with buffered output
- `start()`: Long-running processes with streaming stdout/stderr

**Native Process Management**
- FFI-based process execution for Windows x64 and Linux x64
- Non-blocking I/O for stdout and stderr streams
- Exit code handling and process lifecycle management
- Process timeouts and cancellation support

**Sandboxing**
- Windows: AppContainer integration for isolated process execution
- Linux: Bubblewrap (bwrap) support with filesystem isolation
- Configurable via `WorkspaceOptions.sandbox`
- Automatic fallback to non-sandboxed mode when unavailable

**File Operations**
- `writeFile()`: Write text files relative to workspace root
- `readFile()`: Read text files from workspace
- `exists()`: Check file/directory existence
- `createDir()`: Create directories
- `delete()`: Remove files or directories

**Configuration**
- Configurable timeouts for command execution
- Custom environment variables
- Working directory overrides
- Parent environment inheritance control

**Testing & Quality**
- Integration tests for process execution
- Concurrency and stress tests (10+ concurrent workspaces)
- Security validation tests
- Streaming output tests
- Unit tests for command result and shell parsing
- Cross-platform coverage (Windows & Linux)

### Technical Details

- Built with `dart:ffi` for native C++ interop
- Native core in C++ with platform-specific implementations
- CMake-based build system
- Prebuilt binaries for Windows x64 and Linux x64

### Documentation

- Comprehensive README with examples and API docs
- Inline documentation for all public APIs
- Security notes and best practices for AI agent use cases
- Platform support matrix and known limitations

---

[0.1.1]: https://github.com/deskhand-software/workspace_sandbox/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/deskhand-software/workspace_sandbox/releases/tag/v0.1.0
