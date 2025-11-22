import 'dart:async';

/// Cooperative cancellation token for running processes.
///
/// A [CancellationToken] can be passed to [WorkspaceOptions] to allow
/// programmatic cancellation of long‑running commands.
class CancellationToken {
  final _controller = StreamController<void>.broadcast();
  bool _isCancelled = false;

  /// Creates a new token that is initially not cancelled.
  CancellationToken();

  /// Whether [cancel] has already been requested.
  bool get isCancelled => _isCancelled;

  /// Stream that fires once when [cancel] is called.
  Stream<void> get onCancel => _controller.stream;

  /// Requests cancellation for any operation that is listening to [onCancel].
  ///
  /// Calling this method multiple times has no effect after the first call.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _controller.add(null);
    _controller.close();
  }
}

/// Configuration options for running a command inside a workspace.
///
/// These options control environment variables, working directory,
/// timeouts and optional native sandboxing features.
class WorkspaceOptions {
  /// Maximum execution time before the process is killed.
  ///
  /// If `null`, no timeout is enforced by the library, and the process
  /// will run until it completes or is cancelled manually.
  final Duration? timeout;

  /// Additional environment variables to inject into the process.
  ///
  /// When [includeParentEnv] is `true`, these variables are merged on top of
  /// the host process environment. If a key conflicts, the value in this map
  /// takes precedence.
  final Map<String, String> env;

  /// Whether to inherit the parent process environment variables.
  ///
  /// When `true` (default), [env] extends the existing environment.
  /// When `false`, the process starts with a minimal environment (plus [env]).
  final bool includeParentEnv;

  /// Optional cooperative cancellation token.
  ///
  /// If provided, long‑running operations can observe this token and
  /// terminate early when [CancellationToken.cancel] is invoked.
  final CancellationToken? cancellationToken;

  /// Optional working directory override.
  ///
  /// Must be a relative path to the workspace root. If `null`, the workspace
  /// root directory is used as the current working directory.
  final String? workingDirectoryOverride;

  /// Indicates whether this execution should be sandboxed.
  ///
  /// When `true`, the library attempts to use native OS isolation mechanisms:
  /// - **Linux**: Uses `bubblewrap` (bwrap) to create a container with restricted
  ///   filesystem access and namespaces.
  /// - **Windows**: Uses `AppContainer` to restrict tokens and capabilities.
  ///
  /// Defaults to `false`.
  final bool sandbox;

  /// Controls network access for the sandboxed process.
  ///
  /// - `true` (default): The process can access the network.
  /// - `false`: The process runs in an offline namespace (Linux) or with
  ///   network capabilities stripped (Windows).
  ///
  /// Note: This option is only effective when [sandbox] is `true`.
  final bool allowNetwork;

  /// Creates a new immutable set of options for process execution.
  const WorkspaceOptions({
    this.timeout,
    this.env = const {},
    this.includeParentEnv = true,
    this.cancellationToken,
    this.workingDirectoryOverride,
    this.sandbox = false,
    this.allowNetwork = true,
  });
}
