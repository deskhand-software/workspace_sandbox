import 'dart:async';
import 'dart:io';

import 'core/launcher_service.dart';
import '../workspace_sandbox.dart';

/// Internal implementation of the workspace logic.
///
/// Coordinates between the launcher service (for process execution) and
/// the file system service (for file operations), and manages the central
/// event bus for reactive logging.
///
/// This class is not part of the public API.
class WorkspaceImpl implements Workspace {
  /// Unique identifier for this workspace instance.
  final String id;

  /// Default options applied to all commands unless overridden.
  final WorkspaceOptions defaultOptions;

  /// Whether this workspace should be deleted on dispose.
  final bool isTemporary;

  /// Root directory reference.
  final Directory _directory;

  late final LauncherService _launcher;

  /// File system service for managing workspace files.
  @override
  final FileSystemService fs;

  /// Central event bus for broadcasting workspace events.
  final _eventController = StreamController<WorkspaceEvent>.broadcast();

  /// Stream of all events happening in this workspace.
  @override
  Stream<WorkspaceEvent> get onEvent => _eventController.stream;

  /// Creates a new workspace implementation.
  ///
  /// Parameters:
  /// - [rootPath]: Absolute path to the workspace root
  /// - [id]: Unique identifier for logging
  /// - [options]: Default configuration for all operations
  /// - [isTemporary]: Whether to delete the workspace on dispose
  WorkspaceImpl(String rootPath, this.id,
      {WorkspaceOptions? options, required this.isTemporary})
      : defaultOptions = options ?? const WorkspaceOptions(),
        fs = FileSystemService(rootPath),
        _directory = Directory(rootPath) {
    _launcher = LauncherService(rootPath, id);
  }

  /// Absolute path to the workspace root directory.
  @override
  String get rootPath => fs.rootPath;

  /// Disposes resources and closes the event stream.
  @override
  Future<void> dispose() async {
    await _eventController.close();
    if (isTemporary && await _directory.exists()) {
      try {
        await _directory.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Executes a command and waits for completion.
  ///
  /// Discriminates between shell (String) and binary (`List<String>`) execution.
  Future<CommandResult> exec(Object command,
      {WorkspaceOptions? options}) async {
    final opts = _mergeOptions(options);

    if (command is String) {
      // Shell execution
      final process = await _launcher.spawnShell(command, opts);
      _attachToEventBus(process, command);
      return _collectResult(process);
    } else if (command is List<String>) {
      // Binary execution
      if (command.isEmpty) {
        throw ArgumentError('Command list cannot be empty');
      }
      final executable = command.first;
      final args = command.length > 1 ? command.sublist(1) : <String>[];
      final process = await _launcher.spawnExec(executable, args, opts);
      _attachToEventBus(process, command.join(' '));
      return _collectResult(process);
    } else {
      throw ArgumentError(
          'Command must be String (shell) or List<String> (binary)');
    }
  }

  /// Spawns a command as a background process with streaming output.
  @override
  Future<WorkspaceProcess> execStream(Object command,
      {WorkspaceOptions? options}) async {
    final opts = _mergeOptions(options);

    if (command is String) {
      // Shell execution
      final process = await _launcher.spawnShell(command, opts);
      _attachToEventBus(process, command);
      return process;
    } else if (command is List<String>) {
      // Binary execution
      if (command.isEmpty) {
        throw ArgumentError('Command list cannot be empty');
      }
      final executable = command.first;
      final args = command.length > 1 ? command.sublist(1) : <String>[];
      final process = await _launcher.spawnExec(executable, args, opts);
      _attachToEventBus(process, command.join(' '));
      return process;
    } else {
      throw ArgumentError(
          'Command must be String (shell) or List<String> (binary)');
    }
  }

  /// Attaches a process to the central event bus.
  ///
  /// Emits lifecycle and output events as the process runs.
  void _attachToEventBus(WorkspaceProcess process, String commandLabel) {
    final pid = process.pid;

    // Emit started event
    _eventController.add(ProcessLifecycleEvent(
      workspaceId: id,
      pid: pid,
      command: commandLabel,
      state: ProcessState.started,
    ));

    // Forward stdout events
    process.stdout.listen((data) {
      _eventController.add(ProcessOutputEvent(
        workspaceId: id,
        pid: pid,
        command: commandLabel,
        content: data,
        isError: false,
      ));
    });

    // Forward stderr events
    process.stderr.listen((data) {
      _eventController.add(ProcessOutputEvent(
        workspaceId: id,
        pid: pid,
        command: commandLabel,
        content: data,
        isError: true,
      ));
    });

    // Emit stopped event when process exits
    process.exitCode.then((code) {
      _eventController.add(ProcessLifecycleEvent(
        workspaceId: id,
        pid: pid,
        command: commandLabel,
        state: ProcessState.stopped,
        exitCode: code,
      ));
    });
  }

  /// Merges default options with per-call overrides.
  WorkspaceOptions _mergeOptions(WorkspaceOptions? override) {
    if (override == null) return defaultOptions;

    return WorkspaceOptions(
      timeout: override.timeout ?? defaultOptions.timeout,
      env: {...defaultOptions.env, ...override.env},
      includeParentEnv: override.includeParentEnv,
      cancellationToken:
          override.cancellationToken ?? defaultOptions.cancellationToken,
      workingDirectoryOverride: override.workingDirectoryOverride ??
          defaultOptions.workingDirectoryOverride,
      sandbox: defaultOptions.sandbox || override.sandbox,
      allowNetwork: override.allowNetwork,
    );
  }

  /// Collects the full output from a process into a [CommandResult].
  Future<CommandResult> _collectResult(WorkspaceProcess process) async {
    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();
    final stopwatch = Stopwatch()..start();

    await Future.wait([
      process.stdout.forEach(stdoutBuf.write),
      process.stderr.forEach(stderrBuf.write)
    ]);

    final code = await process.exitCode;
    stopwatch.stop();

    return CommandResult(
      exitCode: code,
      stdout: stdoutBuf.toString(),
      stderr: stderrBuf.toString(),
      duration: stopwatch.elapsed,
      isCancelled: process.isCancelled,
    );
  }
}
