/// A robust, sandboxed workspace manager for executing shell commands securely.
///
/// This library provides cross-platform process isolation using native
/// sandboxing mechanisms (Bubblewrap on Linux, Job Objects on Windows,
/// Seatbelt on macOS) to execute commands in controlled environments.
///
/// ## Features
/// - **Ephemeral workspaces**: Temporary sandboxed directories that auto-clean
/// - **Persistent workspaces**: Work on existing project directories
/// - **Network isolation**: Block network access per workspace
/// - **Real-time events**: Stream stdout/stderr and lifecycle events
/// - **File system helpers**: Tree visualization, grep, glob search
///
/// ## Example
///
/// ```
/// import 'package:workspace_sandbox/workspace_sandbox.dart';
///
/// void main() async {
///   final ws = Workspace.ephemeral();
///
///   // Shell command (with pipes)
///   await ws.exec('echo "Hello" | grep Hello');
///
///   // Binary execution (injection-proof)
///   await ws.exec(['git', 'status']);
///
///   await ws.dispose();
/// }
/// ```
library workspace_sandbox;

import 'dart:io';
import 'dart:math';

import 'src/workspace_impl.dart';
import 'src/models/command_result.dart';
import 'src/models/workspace_options.dart';
import 'src/models/workspace_process.dart';
import 'src/models/workspace_event.dart';
import 'src/fs/file_system_service.dart';

export 'src/models/command_result.dart';
export 'src/models/workspace_options.dart';
export 'src/models/workspace_process.dart';
export 'src/models/workspace_event.dart';
export 'src/fs/file_system_service.dart';
export 'src/core/path_security.dart' show SecurityException;

/// Represents a secure, isolated workspace for executing commands.
///
/// A workspace provides an isolated environment with sandboxing capabilities
/// for running shell commands, managing files, and observing process output.
///
/// Use [Workspace.ephemeral] for temporary workspaces that auto-clean, or
/// [Workspace.at] to work on existing directories.
abstract class Workspace {
  /// The absolute path to the workspace root directory.
  String get rootPath;

  /// A unified stream of all events happening in this workspace.
  ///
  /// Emits:
  /// - [ProcessLifecycleEvent]: Process start/stop events
  /// - [ProcessOutputEvent]: Real-time stdout/stderr chunks
  ///
  /// This stream is broadcast and can have multiple listeners.
  Stream<WorkspaceEvent> get onEvent;

  /// File system service for managing workspace files and directories.
  ///
  /// Provides secure file operations with automatic path validation.
  FileSystemService get fs;

  /// Creates a temporary workspace in the system temp directory.
  ///
  /// The workspace is automatically sandboxed and will be deleted when
  /// [dispose] is called.
  ///
  /// Example:
  /// ```
  /// final ws = Workspace.ephemeral();
  /// print(ws.rootPath); // /tmp/ws_sb_a1b2c3d4/
  /// await ws.dispose(); // Directory is deleted
  /// ```
  ///
  /// Parameters:
  /// - [id]: Optional unique identifier for logging/debugging
  /// - [options]: Optional configuration (timeout, env vars, network access)
  factory Workspace.ephemeral({String? id, WorkspaceOptions? options}) {
    final wsId = id ?? _generateId();
    final tempDir = Directory.systemTemp.createTempSync('ws_sb_$wsId');
    final secureOpts =
        (options ?? const WorkspaceOptions()).copyWith(sandbox: true);
    return WorkspaceImpl(tempDir.path, wsId,
        options: secureOpts, isTemporary: true);
  }

  /// Creates a workspace at an existing directory path.
  ///
  /// The workspace is persistent and will NOT be deleted on [dispose].
  /// If the directory doesn't exist, it will be created.
  ///
  /// Example:
  /// ```
  /// final ws = Workspace.at('/path/to/project');
  /// await ws.exec('git status');
  /// await ws.dispose(); // Files are preserved
  /// ```
  ///
  /// Parameters:
  /// - [path]: Absolute path to the workspace directory
  /// - [id]: Optional unique identifier
  /// - [options]: Optional configuration
  factory Workspace.at(String path, {String? id, WorkspaceOptions? options}) {
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return WorkspaceImpl(dir.path, id ?? _generateId(),
        options: options, isTemporary: false);
  }

  // --- EXECUTION ---

  /// Executes a command and waits for completion.
  ///
  /// **Type Discrimination:**
  /// - If [command] is a `String`, executes via system shell (`/bin/sh` or `cmd.exe`)
  ///   allowing pipes, redirections, and shell features.
  /// - If [command] is a `List<String>`, executes the binary directly without shell
  ///   interpretation (safer, prevents injection).
  ///
  /// Example:
  /// ```
  /// // Shell command (supports pipes)
  /// final result1 = await ws.exec('ls -la | grep dart');
  ///
  /// // Direct binary execution (injection-proof)
  /// final result2 = await ws.exec(['git', 'commit', '-m', 'feat: new feature']);
  /// ```
  ///
  /// Returns a [CommandResult] with exit code, stdout, stderr, and duration.
  Future<CommandResult> exec(Object command, {WorkspaceOptions? options});

  /// Spawns a command as a background process with streaming output.
  ///
  /// Returns immediately with a [WorkspaceProcess] handle for streaming
  /// stdout/stderr and waiting for completion.
  ///
  /// **Type Discrimination:** Same as [exec]
  /// - `String`: Shell command
  /// - `List<String>`: Direct binary
  ///
  /// Example:
  /// ```
  /// // Stream shell output
  /// final process = await ws.execStream('python app.py');
  /// await for (final line in process.stdout) {
  ///   print('Output: $line');
  /// }
  ///
  /// // Stream binary output
  /// final process2 = await ws.execStream(['node', 'server.js']);
  /// final exitCode = await process2.exitCode;
  /// ```
  Future<WorkspaceProcess> execStream(Object command,
      {WorkspaceOptions? options});

  /// Disposes the workspace and cleans up resources.
  ///
  /// For ephemeral workspaces, deletes the temporary directory.
  /// For persistent workspaces, only closes internal resources.
  ///
  /// Always call this when done with the workspace.
  Future<void> dispose();
}

/// Generates a random 8-character alphanumeric ID.
String _generateId() {
  final rnd = Random();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
}
