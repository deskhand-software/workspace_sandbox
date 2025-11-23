import 'dart:io';
import 'package:path/path.dart' as p;

class FileSystemHelpers {
  /// Robust Tree implementation (Flatten strategy for OS consistency)
  static Future<String> tree(String rootPath, {int maxDepth = 5}) async {
    final dir = Directory(rootPath);
    if (!await dir.exists()) return '';

    final buffer = StringBuffer();
    buffer.writeln(p.basename(rootPath));

    List<FileSystemEntity> entities;
    try {
      // Atomic fetch
      await Future.delayed(const Duration(milliseconds: 10));
      entities = await dir.list(recursive: true, followLinks: false).toList();
    } catch (_) {
      return buffer.toString();
    }

    final paths = <String>[];
    for (var entity in entities) {
      final relative = p.relative(entity.path, from: rootPath);
      final parts = p.split(relative);
      if (parts.length > maxDepth) continue;
      if (parts.any((part) => part.startsWith('.'))) continue;
      paths.add(relative);
    }

    paths.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (paths.isEmpty) return buffer.toString();

    final openLevels = <int, bool>{};

    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      final parts = p.split(path);
      final level = parts.length - 1;
      final name = parts.last;

      bool isLast = true;
      if (i + 1 < paths.length) {
        final nextPath = paths[i + 1];
        final nextParts = p.split(nextPath);
        if (nextParts.length > level) {
          final currentParent =
              level == 0 ? '' : p.joinAll(parts.sublist(0, level));
          final nextParent =
              level == 0 ? '' : p.joinAll(nextParts.sublist(0, level));
          if (currentParent == nextParent) isLast = false;
        }
      }

      openLevels[level] = !isLast;

      var prefix = '';
      for (var k = 0; k < level; k++) {
        prefix += (openLevels[k] ?? false) ? '│   ' : '    ';
      }

      buffer.writeln('$prefix${isLast ? '└── ' : '├── '}$name');
    }

    return buffer.toString();
  }

  static Future<String> grep(String rootPath, String pattern,
      {bool recursive = true, bool caseSensitive = true}) async {
    final results = <String>[];
    final dir = Directory(rootPath);
    if (!await dir.exists()) return '';
    Stream<FileSystemEntity> stream =
        dir.list(recursive: recursive, followLinks: false);
    try {
      await for (final entity in stream) {
        if (entity is File) {
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
                results.add(
                    '$relPath:${i + 1}: ${line.trim().length > 100 ? line.trim().substring(0, 100) + "..." : line.trim()}');
                if (results.length > 500) {
                  results.add('...');
                  return results.join('\n');
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return results.join('\n');
  }

  static Future<List<String>> find(String rootPath, String pattern) async {
    final results = <String>[];
    final dir = Directory(rootPath);
    if (!await dir.exists()) return [];
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

  static Future<void> copy(String srcPath, String destPath) async {
    final type = await FileSystemEntity.type(srcPath);
    if (type == FileSystemEntityType.file) {
      await File(srcPath).copy(destPath);
    } else if (type == FileSystemEntityType.directory) {
      await Directory(destPath).create(recursive: true);
      await for (final entity in Directory(srcPath).list(recursive: false)) {
        await copy(entity.path, p.join(destPath, p.basename(entity.path)));
      }
    }
  }

  // Implementación simple de move para WorkspaceImpl
  static Future<void> move(String srcPath, String destPath) async {
    final type = await FileSystemEntity.type(srcPath);
    // Asegurar directorio destino existe
    await Directory(p.dirname(destPath)).create(recursive: true);

    if (type == FileSystemEntityType.file) {
      await File(srcPath).rename(destPath);
    } else if (type == FileSystemEntityType.directory) {
      await Directory(srcPath).rename(destPath);
    }
  }

  // Implementación simple de delete para WorkspaceImpl
  static Future<void> delete(String path) async {
    final type = await FileSystemEntity.type(path);
    if (type == FileSystemEntityType.file) {
      await File(path).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(path).delete(recursive: true);
    }
  }
}
