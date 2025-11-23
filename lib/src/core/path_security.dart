// lib/src/core/path_security.dart
import 'dart:io';
import 'package:path/path.dart' as p;

class PathSecurity {
  final String rootPath;

  PathSecurity(this.rootPath);

  /// Resolves a relative path to an absolute path securely.
  String resolve(String relativePath) {
    final cleanRel = p.normalize(relativePath);

    // Jailbreak check
    if (cleanRel.startsWith('..') ||
        (p.isAbsolute(relativePath) && !relativePath.startsWith(rootPath))) {
      throw FileSystemException(
          'Security Error: Path attempts to escape workspace root.',
          relativePath);
    }

    return p.join(rootPath, cleanRel);
  }
}
