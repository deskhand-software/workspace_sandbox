import 'dart:io';
import '../core/path_security.dart'; // Asumiendo que ya creaste esto según el paso anterior
import '../util/file_system_helpers.dart'; // Importamos la utilidad de bajo nivel

class FileSystemService {
  final PathSecurity _security;

  FileSystemService(String rootPath) : _security = PathSecurity(rootPath);

  String get rootPath => _security.rootPath;

  // --- Operaciones Básicas ---

  Future<File> writeFile(String relativePath, String content) async {
    final file = File(_security.resolve(relativePath));
    await file.parent.create(recursive: true);
    return file.writeAsString(content);
  }

  Future<String> readFile(String relativePath) async {
    final file = File(_security.resolve(relativePath));
    if (!await file.exists()) {
      throw FileSystemException('File not found', relativePath);
    }
    return file.readAsString();
  }

  Future<File> writeBytes(String relativePath, List<int> bytes) async {
    final file = File(_security.resolve(relativePath));
    await file.parent.create(recursive: true);
    return file.writeAsBytes(bytes);
  }

  Future<List<int>> readBytes(String relativePath) async {
    final file = File(_security.resolve(relativePath));
    if (!await file.exists()) {
      throw FileSystemException('File not found', relativePath);
    }
    return file.readAsBytes();
  }

  Future<Directory> createDir(String relativePath) async {
    final dir = Directory(_security.resolve(relativePath));
    return dir.create(recursive: true);
  }

  Future<bool> exists(String relativePath) async {
    final path = _security.resolve(relativePath);
    return await File(path).exists() || await Directory(path).exists();
  }

  // --- Operaciones Avanzadas (Delegadas a Helpers) ---

  Future<String> tree({int? maxDepth}) async {
    // Aquí centralizamos el valor por defecto (5)
    final depth = maxDepth ?? 5;
    return FileSystemHelpers.tree(_security.rootPath, maxDepth: depth);
  }

  Future<String> grep(String pattern,
      {bool recursive = true, bool caseSensitive = true}) async {
    return FileSystemHelpers.grep(_security.rootPath, pattern,
        recursive: recursive, caseSensitive: caseSensitive);
  }

  Future<List<String>> find(String pattern) async {
    return FileSystemHelpers.find(_security.rootPath, pattern);
  }

  Future<void> copy(String srcRel, String destRel) async {
    await FileSystemHelpers.copy(
        _security.resolve(srcRel), _security.resolve(destRel));
  }

  Future<void> move(String srcRel, String destRel) async {
    await FileSystemHelpers.move(
        _security.resolve(srcRel), _security.resolve(destRel));
  }

  Future<void> delete(String relativePath) async {
    await FileSystemHelpers.delete(_security.resolve(relativePath));
  }
}
