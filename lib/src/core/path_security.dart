import 'package:path/path.dart' as p;

/// Security utility for validating and resolving file paths within a workspace.
///
/// Prevents path traversal attacks by ensuring all resolved paths stay within
/// the workspace root directory using canonical path validation.
class PathSecurity {
  /// The absolute, normalized path to the workspace root directory.
  final String rootPath;

  /// Creates a path security validator for the given workspace root.
  ///
  /// The [rootPath] is normalized and canonicalized during construction.
  ///
  /// Example:
  /// ```
  /// final security = PathSecurity('/tmp/workspace');
  /// final safePath = security.resolve('config.json'); // OK
  /// security.resolve('../../../etc/passwd'); // Throws SecurityException
  /// ```
  PathSecurity(String rootPath)
      : rootPath = p.canonicalize(p.absolute(rootPath));

  /// Resolves a relative path to an absolute path within the workspace.
  ///
  /// Validates that the resolved path does not escape the workspace root
  /// directory using path traversal sequences like `..`.
  ///
  /// This method uses [p.isWithin] to perform secure canonical validation,
  /// which prevents ALL forms of path traversal including:
  /// - Direct: `../../../etc/passwd`
  /// - Indirect: `subdir/../../etc/passwd`
  /// - Mixed: `./valid/../../../etc/passwd`
  ///
  /// Parameters:
  /// - [relativePath]: A relative path within the workspace
  ///
  /// Returns the absolute, normalized path within the workspace.
  ///
  /// Throws [SecurityException] if the path escapes the workspace root.
  ///
  /// Example:
  /// ```
  /// final security = PathSecurity('/workspace');
  /// security.resolve('src/main.dart');     // -> /workspace/src/main.dart
  /// security.resolve('../secrets');        // -> SecurityException
  /// security.resolve('a/../../etc/passwd'); // -> SecurityException
  /// ```
  String resolve(String relativePath) {
    // Normalize the input path
    final normalized = p.normalize(relativePath);

    // Reject absolute paths outright
    if (p.isAbsolute(normalized)) {
      throw SecurityException(
        'Absolute paths are not allowed in workspace operations',
        relativePath,
      );
    }

    // Join with workspace root and canonicalize
    final candidate = p.canonicalize(p.join(rootPath, normalized));

    // Use canonical "within" check (handles all traversal cases)
    if (!p.isWithin(rootPath, candidate) && candidate != rootPath) {
      throw SecurityException(
        'Path traversal detected: resolved path escapes workspace root',
        relativePath,
      );
    }

    return candidate;
  }
}

/// Exception thrown when a path validation fails due to security violations.
///
/// This is thrown by [PathSecurity.resolve] when a path attempts to escape
/// the workspace root directory.
class SecurityException implements Exception {
  /// Human-readable error message.
  final String message;

  /// The original path that triggered the violation.
  final String path;

  /// Creates a security exception.
  SecurityException(this.message, this.path);

  @override
  String toString() => 'SecurityException: $message (path: "$path")';
}
