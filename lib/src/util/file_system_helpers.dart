import 'dart:io';
import 'package:path/path.dart' as p;

/// Utility class containing helper methods for file system operations.
///
/// These methods are implemented in pure Dart and do not rely on native
/// OS commands (like `ls` or `grep`), ensuring consistent behavior across platforms.
class FileSystemHelpers {
  /// Generates a visual tree-like string representation of the directory structure.
  ///
  /// [rootPath] is the absolute path to the directory to visualize.
  /// [maxDepth] limits how deep the recursion goes (default 5).
  static Future<String> tree(String rootPath, {int maxDepth = 5}) async {
    final buffer = StringBuffer();
    final dir = Directory(rootPath);

    if (!await dir.exists()) return '';

    // Add root folder name
    buffer.writeln(p.basename(rootPath));

    await _treeRecursive(dir, '', 0, maxDepth, buffer);
    return buffer.toString();
  }

  static Future<void> _treeRecursive(
    Directory dir,
    String prefix,
    int currentDepth,
    int maxDepth,
    StringBuffer buffer,
  ) async {
    if (currentDepth >= maxDepth) return;

    try {
      final entities = await dir.list(followLinks: false).toList();

      // Sort: Directories first, then files (case-insensitive)
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });

      for (var i = 0; i < entities.length; i++) {
        final entity = entities[i];
        final isLast = i == entities.length - 1;
        final name = p.basename(entity.path);

        // Skip common hidden files
        if (name.startsWith('.')) continue;

        buffer.writeln('$prefix${isLast ? '└── ' : '├── '}$name');

        if (entity is Directory) {
          await _treeRecursive(
            entity,
            '$prefix${isLast ? '    ' : '│   '}',
            currentDepth + 1,
            maxDepth,
            buffer,
          );
        }
      }
    } catch (_) {
      // Ignore access denied errors gracefully
      buffer.writeln('$prefix└── [Access Denied]');
    }
  }

  /// Searches for a text [pattern] within files in [rootPath].
  ///
  /// Returns a string with matches formatted as "relative_path:line: content".
  /// Skips known binary file extensions to avoid noise.
  static Future<String> grep(
    String rootPath,
    String pattern, {
    bool recursive = true,
    bool caseSensitive = true,
  }) async {
    final results = <String>[];
    final dir = Directory(rootPath);

    if (!await dir.exists()) return '';

    Stream<FileSystemEntity> stream =
        dir.list(recursive: recursive, followLinks: false);

    try {
      await for (final entity in stream) {
        if (entity is File) {
          // Heuristic: Skip binary files based on extension
          const binaryExts = {
            '.png',
            '.jpg',
            '.jpeg',
            '.gif',
            '.bmp',
            '.exe',
            '.dll',
            '.so',
            '.dylib',
            '.bin',
            '.zip',
            '.tar',
            '.gz',
            '.pdf',
            '.ico'
          };
          if (binaryExts.contains(p.extension(entity.path).toLowerCase()))
            continue;

          try {
            final lines = await entity.readAsLines();
            for (var i = 0; i < lines.length; i++) {
              final line = lines[i];
              final match = caseSensitive
                  ? line.contains(pattern)
                  : line.toLowerCase().contains(pattern.toLowerCase());

              if (match) {
                final relPath = p.relative(entity.path, from: rootPath);
                // Truncate very long lines for readability
                String preview = line.trim();
                if (preview.length > 100)
                  preview = '${preview.substring(0, 100)}...';

                results.add('$relPath:${i + 1}: $preview');

                // Safety break to prevent huge outputs
                if (results.length > 500) {
                  results.add('... (search limit reached)');
                  return results.join('\n');
                }
              }
            }
          } catch (_) {
            // Ignore encoding errors (likely binary file)
          }
        }
      }
    } catch (_) {}

    return results.join('\n');
  }

  /// Finds files matching a simple glob-like [pattern] (e.g., "*.dart").
  static Future<List<String>> find(String rootPath, String pattern) async {
    final results = <String>[];
    final dir = Directory(rootPath);
    if (!await dir.exists()) return [];

    // Convert simple wildcard pattern to Regex
    final regex = RegExp(
        '^' +
            RegExp.escape(pattern)
                .replaceAll(r'\*', '.*')
                .replaceAll(r'\?', '.') +
            '\$',
        caseSensitive: false);

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (regex.hasMatch(p.basename(entity.path))) {
        results.add(p.relative(entity.path, from: rootPath));
      }
    }
    return results;
  }

  /// Copies a file or directory from [srcPath] to [destPath] recursively.
  static Future<void> copy(String srcPath, String destPath) async {
    final type = await FileSystemEntity.type(srcPath);
    if (type == FileSystemEntityType.file) {
      final file = File(srcPath);
      await Directory(p.dirname(destPath)).create(recursive: true);
      await file.copy(destPath);
    } else if (type == FileSystemEntityType.directory) {
      await _copyDir(Directory(srcPath), Directory(destPath));
    }
  }

  static Future<void> _copyDir(Directory src, Directory dest) async {
    await dest.create(recursive: true);
    await for (final entity in src.list(recursive: false)) {
      final newPath = p.join(dest.path, p.basename(entity.path));
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDir(entity, Directory(newPath));
      }
    }
  }
}
