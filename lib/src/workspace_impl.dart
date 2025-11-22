import 'dart:async';
import 'package:ffi/ffi.dart' as ffi_helpers;

import 'models/command_result.dart';
import 'models/workspace_options.dart';
import 'models/workspace_process.dart';
import 'native/ffi_bridge.dart';
import 'native/native_process_impl.dart';
import 'security/security_guard.dart';
import 'util/shell_parser.dart';

/// Internal implementation that bridges [Workspace] to the native core.
///
/// This class is responsible for orchestrating the security checks and
/// initiating native processes via FFI. It effectively hides the complexity
/// of resource management (Arenas, pointers) from the public API.
class WorkspaceImpl {
  final String rootPath;
  final String id;
  final WorkspaceOptions _defaultOptions;

  WorkspaceImpl(
    this.rootPath,
    this.id, {
    WorkspaceOptions? options,
  }) : _defaultOptions = options ?? const WorkspaceOptions();

  /// Runs [commandLine] to completion and returns an aggregated [CommandResult].
  ///
  /// Captures both stdout and stderr into memory. For long-running processes
  /// or large outputs, consider using [start] to stream data instead.
  Future<CommandResult> run(
    String commandLine, {
    WorkspaceOptions? options,
  }) async {
    WorkspaceProcess process;
    try {
      process = await start(commandLine, options: options);
    } catch (e) {
      return CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Failed to start process: $e',
        duration: Duration.zero,
      );
    }

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    final outSub = process.stdout.listen(stdoutBuf.write);
    final errSub = process.stderr.listen(stderrBuf.write);

    final code = await process.exitCode;

    await outSub.cancel();
    await errSub.cancel();

    // Check if cancelled internally (e.g., timeout)
    bool isCancelled = false;
    if (process is NativeProcessImpl) {
      isCancelled = process.isCancelled;
    }

    return CommandResult(
      exitCode: code,
      stdout: stdoutBuf.toString(),
      stderr: stderrBuf.toString(),
      duration: Duration.zero, // TODO: Implement precise duration measurement
      isCancelled: isCancelled,
    );
  }

  /// Starts a new process using the native core and returns a [WorkspaceProcess].
  ///
  /// This method performs a security inspection via [SecurityGuard] before
  /// executing the command. If the command violates the security policy
  /// (e.g., network access when forbidden), it throws an exception.
  Future<WorkspaceProcess> start(
    String commandLine, {
    WorkspaceOptions? options,
  }) async {
    final opts = options ?? _defaultOptions;

    // 1. Security Check (Dart Layer)
    // Prevents execution of known dangerous commands before they reach the OS.
    SecurityGuard.inspectCommand(commandLine, opts);

    final workingDirectory = opts.workingDirectoryOverride ?? rootPath;
    final arena = ffi_helpers.Arena();

    final finalCommandLine = ShellParser.prepareCommand(commandLine);

    try {
      // 2. Native Execution
      final handle = FfiBridge.start(
        finalCommandLine,
        workingDirectory,
        opts.sandbox,
        id,
        opts.allowNetwork,
        arena,
      );

      if (handle.address == 0) {
        throw Exception(
          'Native failure: could not start process "$finalCommandLine".',
        );
      }

      // 3. Return Wrapped Process
      // NativeProcessImpl handles the polling loop and resource cleanup.
      return NativeProcessImpl(handle, arena, timeout: opts.timeout);
    } catch (e) {
      arena.releaseAll();
      rethrow;
    }
  }
}
