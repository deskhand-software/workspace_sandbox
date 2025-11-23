/// A robust, sandboxed workspace manager for executing shell commands securely.
///
/// This library provides a high-level API to create isolated file system environments
/// and execute commands within them. It supports both ephemeral (temporary) workspaces
/// and persistent (host-based) workspaces.
///
/// Primary features:
/// * **Isolation**: Uses native OS features (AppContainer on Windows, Bubblewrap on Linux).
/// * **Observability**: Methods like [tree], [grep], and [readSlice] for inspecting state.
/// * **Resource Management**: Automatic cleanup of temporary directories.
library workspace_sandbox;

import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;

import 'src/util/file_system_helpers.dart';
import 'src/workspace_impl.dart';
import 'src/models/command_result.dart';
import 'src/models/workspace_options.dart';
import 'src/models/workspace_process.dart';

export 'src/models/command_result.dart';
export 'src/models/workspace_options.dart';
export 'src/models/workspace_process.dart';

/// Represents a secure, isolated workspace directory.
///
/// Workspaces can be ephemeral (created in system temp) or persistent (mapped to a host directory).
/// Commands run within the workspace are isolated where supported by the OS.
class Workspace {
  final WorkspaceImpl _impl;
  final Directory _directory;
  final bool _isTemporary;

  /// Internal flag to track if this workspace was initialized as "secure".
  final bool _enforceSandbox;

  /// Stable identifier for this workspace instance.
  final String id;

  /// Private constructor. Use [Workspace.secure] or [Workspace.host].
  Workspace._(
    this._directory,
    this._isTemporary,
    this.id, {
    WorkspaceOptions? options,
    bool enforceSandbox = false,
  })  : _enforceSandbox = enforceSandbox,
        _impl = WorkspaceImpl(_directory.path, id, options: options);

  /// The absolute path to the workspace root.
  String get rootPath => _directory.path;

  /// Creates a secure, ephemeral workspace in the system temp directory.
  ///
  /// The workspace is automatically cleaned up when [dispose] is called.
  /// Sandboxing is **enforced** by default for all commands run in this workspace.
  ///
  /// [id] is an optional unique identifier for the workspace (defaults to random string).
  /// [options] configures default execution behavior. Note that `sandbox: true` will
  /// be forced regardless of the value passed here.
  factory Workspace.secure({
    String? id,
    WorkspaceOptions? options,
  }) {
    final workspaceId = id ?? _generateId();
    final tempDir =
        Directory.systemTemp.createTempSync('workspace_sandbox_$workspaceId');

    // Force sandbox=true for secure workspaces
    final baseOpts = options ?? const WorkspaceOptions();
    final secureOpts = WorkspaceOptions(
      sandbox: true, // ALWAYS true for secure()
      timeout: baseOpts.timeout,
      env: baseOpts.env,
      includeParentEnv: baseOpts.includeParentEnv,
      cancellationToken: baseOpts.cancellationToken,
      workingDirectoryOverride: baseOpts.workingDirectoryOverride,
      allowNetwork: baseOpts.allowNetwork,
    );

    return Workspace._(
      tempDir,
      true,
      workspaceId,
      options: secureOpts,
      enforceSandbox: true, // Mark as enforced
    );
  }

  /// Creates a workspace wrapper around an existing host directory.
  ///
  /// Files in this directory persist after [dispose] is called.
  /// Sandboxing is optional and configured via [options].
  ///
  /// [path] must be a valid directory path.
  /// [id] is optional; if not provided, a random one is generated.
  factory Workspace.host(
    String path, {
    String? id,
    WorkspaceOptions? options,
  }) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return Workspace._(dir, false, id ?? _generateId(), options: options);
  }

  /// Executes a command and waits for it to complete.
  ///
  /// Returns a [CommandResult] containing the exit code, stdout, and stderr.
  ///
  /// [commandLine] is the full shell command string (e.g., 'npm install').
  /// [options] overrides the default workspace options for this execution.
  Future<CommandResult> run(
    String commandLine, {
    WorkspaceOptions? options,
  }) {
    final effectiveOptions = _mergeOptions(options);
    return _impl.run(commandLine, options: effectiveOptions);
  }

  /// Starts a long-running process and returns a handle to stream output.
  ///
  /// Returns a [WorkspaceProcess] which exposes `stdout` and `stderr` streams.
  /// Useful for interactive applications or monitoring long tasks.
  Future<WorkspaceProcess> start(
    String commandLine, {
    WorkspaceOptions? options,
  }) {
    final effectiveOptions = _mergeOptions(options);
    return _impl.start(commandLine, options: effectiveOptions);
  }

  /// Helper to merge user-provided options with workspace security policies.
  WorkspaceOptions? _mergeOptions(WorkspaceOptions? userOpts) {
    if (!_enforceSandbox) return userOpts;

    // If this is a secure workspace, we MUST enforce sandbox: true
    // even if the user passed sandbox: false in this specific call.
    if (userOpts == null)
      return null; // Use defaults (which are already secure)

    return WorkspaceOptions(
      sandbox: true, // FORCED override
      timeout: userOpts.timeout,
      env: userOpts.env,
      includeParentEnv: userOpts.includeParentEnv,
      cancellationToken: userOpts.cancellationToken,
      workingDirectoryOverride: userOpts.workingDirectoryOverride,
      allowNetwork: userOpts.allowNetwork, // User can still control network
    );
  }

  // --- FILE SYSTEM OPERATIONS ---

  /// Writes text content to a file relative to the workspace root.
  ///
  /// Creates parent directories automatically if they do not exist.
  Future<File> writeFile(String relativePath, String content) async {
    final file = File(_resolve(relativePath));
    await file.parent.create(recursive: true);
    return file.writeAsString(content);
  }

  /// Reads text content from a file relative to the workspace root.
  ///
  /// Throws [FileSystemException] if the file does not exist.
  Future<String> readFile(String relativePath) async {
    final file = File(_resolve(relativePath));
    if (!await file.exists()) {
      throw FileSystemException('File not found', relativePath);
    }
    return file.readAsString();
  }

  /// Writes binary data to a file relative to the workspace root.
  Future<File> writeBytes(String relativePath, List<int> bytes) async {
    final file = File(_resolve(relativePath));
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes);
  }

  /// Reads binary data from a file relative to the workspace root.
  Future<List<int>> readBytes(String relativePath) async {
    final file = File(_resolve(relativePath));
    if (!await file.exists()) {
      throw FileSystemException('File not found', relativePath);
    }
    return file.readAsBytes();
  }

  /// Generates a visual tree structure of the workspace directory.
  ///
  /// [maxDepth] controls how deep the traversal goes (default: 5).
  Future<String> tree({int maxDepth = 5}) async {
    return FileSystemHelpers.tree(rootPath, maxDepth: maxDepth);
  }

  /// Searches for a text [pattern] inside files within the workspace.
  ///
  /// Returns a formatted string with matches.
  /// [recursive] defaults to true.
  Future<String> grep(String pattern,
      {bool recursive = true, bool caseSensitive = true}) async {
    return FileSystemHelpers.grep(rootPath, pattern,
        recursive: recursive, caseSensitive: caseSensitive);
  }

  /// Finds files matching a simple name pattern (e.g., "*.js").
  Future<List<String>> find(String pattern) async {
    return FileSystemHelpers.find(rootPath, pattern);
  }

  /// Copies a file or directory from [sourceRelPath] to [destRelPath].
  ///
  /// Both paths are relative to the workspace root.
  Future<void> copy(String sourceRelPath, String destRelPath) async {
    final src = _resolve(sourceRelPath);
    final dest = _resolve(destRelPath);
    await FileSystemHelpers.copy(src, dest);
  }

  /// Moves (renames) a file or directory within the workspace.
  Future<void> move(String sourceRelPath, String destRelPath) async {
    final src = _resolve(sourceRelPath);
    final dest = _resolve(destRelPath);

    // Ensure destination parent exists
    await Directory(p.dirname(dest)).create(recursive: true);

    // Use File or Directory rename depending on type
    final type = await FileSystemEntity.type(src);
    if (type == FileSystemEntityType.file) {
      await File(src).rename(dest);
    } else {
      await Directory(src).rename(dest);
    }
  }

  /// Creates a directory relative to the workspace root.
  Future<Directory> createDir(String relativePath) async {
    final dir = Directory(_resolve(relativePath));
    return dir.create(recursive: true);
  }

  /// Deletes a file or directory relative to the workspace root.
  ///
  /// If [relativePath] is a directory, it is deleted recursively.
  Future<void> delete(String relativePath) async {
    final path = _resolve(relativePath);
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    }
  }

  /// Checks if a file or directory exists relative to the workspace root.
  Future<bool> exists(String relativePath) async {
    final path = _resolve(relativePath);
    return await File(path).exists() || await Directory(path).exists();
  }

  /// Cleans up workspace resources.
  ///
  /// If the workspace was created via [Workspace.secure], this deletes
  /// the temporary directory and all its contents.
  Future<void> dispose() async {
    if (_isTemporary && await _directory.exists()) {
      try {
        await _directory.delete(recursive: true);
      } catch (_) {
        // Silently ignore cleanup errors in production.
      }
    }
  }

  /// Resolves a relative path to an absolute path within the workspace.
  ///
  /// Throws [Exception] if the path attempts to escape the workspace (e.g. "../").
  String _resolve(String relativePath) {
    // Normalize path separators
    final cleanRel = p.normalize(relativePath);

    // Basic jailbreak check
    if (cleanRel.startsWith('..') ||
        (p.isAbsolute(relativePath) && !relativePath.startsWith(rootPath))) {
      throw Exception(
          'Security Error: Path "$relativePath" attempts to escape workspace root.');
    }

    return p.join(rootPath, cleanRel);
  }
}

// Internal helper to generate random IDs without external dependencies
String _generateId() {
  final rnd = Random();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
}
