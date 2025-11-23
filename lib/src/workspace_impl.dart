import 'dart:async';
import 'dart:io';

import 'models/command_result.dart';
import 'models/workspace_options.dart';
import 'models/workspace_process.dart';
import 'native/native_process_impl.dart';
import 'core/launcher_service.dart';
import 'fs/file_system_service.dart';

class WorkspaceImpl {
  final String id;
  final WorkspaceOptions _defaultOptions;

  // Composición: Servicios especializados
  final LauncherService _launcher;
  final FileSystemService fs; // Público para acceso directo si se requiere

  WorkspaceImpl(String rootPath, this.id, {WorkspaceOptions? options})
      : _defaultOptions = options ?? const WorkspaceOptions(),
        _launcher = LauncherService(rootPath, id),
        fs = FileSystemService(rootPath);

  String get rootPath => fs.rootPath;

  // --- FILE SYSTEM DELEGATES (Sugar Syntax) ---
  // Exponemos los métodos del servicio FS directamente para mantener la API limpia

  Future<File> writeFile(String path, String content) =>
      fs.writeFile(path, content);

  Future<String> readFile(String path) => fs.readFile(path);

  Future<File> writeBytes(String path, List<int> bytes) =>
      fs.writeBytes(path, bytes);

  Future<List<int>> readBytes(String path) => fs.readBytes(path);

  Future<String> tree({int? maxDepth}) => fs.tree(maxDepth: maxDepth);

  Future<String> grep(String pattern,
          {bool recursive = true, bool caseSensitive = true}) =>
      fs.grep(pattern, recursive: recursive, caseSensitive: caseSensitive);

  Future<List<String>> find(String pattern) => fs.find(pattern);

  Future<void> copy(String src, String dest) => fs.copy(src, dest);

  Future<void> move(String src, String dest) => fs.move(src, dest);

  Future<Directory> createDir(String path) => fs.createDir(path);

  Future<void> delete(String path) => fs.delete(path);

  Future<bool> exists(String path) => fs.exists(path);

  Future<void> dispose() async {
    // Cleanup logic if needed handled by Workspace wrapper usually
  }

  // --- PROCESS EXECUTION ---

  Future<CommandResult> run(String commandLine,
      {WorkspaceOptions? options}) async {
    WorkspaceProcess process;
    try {
      process = await start(commandLine, options: options);
    } catch (e) {
      return CommandResult(
        exitCode: 99,
        stdout: '',
        stderr: 'Start Error: $e',
        duration: Duration.zero,
      );
    }

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();
    final stopwatch = Stopwatch()..start();

    // Escuchar ambos streams completamente
    await Future.wait([
      process.stdout.forEach(stdoutBuf.write),
      process.stderr.forEach(stderrBuf.write)
    ]);

    final code = await process.exitCode;
    stopwatch.stop();

    bool cancelled =
        (process is NativeProcessImpl) ? process.isCancelled : (code == -1);

    return CommandResult(
      exitCode: code,
      stdout: stdoutBuf.toString(),
      stderr: stderrBuf.toString(),
      duration: stopwatch.elapsed,
      isCancelled: cancelled,
    );
  }

  Future<WorkspaceProcess> start(String commandLine,
      {WorkspaceOptions? options}) {
    final opts = options ?? _defaultOptions;
    // Delegamos al servicio de lanzamiento que maneja binarios y argumentos
    return _launcher.spawn(commandLine, opts);
  }
}
