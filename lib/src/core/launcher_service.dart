// lib/src/core/launcher_service.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/workspace_options.dart';
import '../models/workspace_process.dart';
import '../native/native_process_impl.dart';

class LauncherService {
  final String rootPath;
  final String id;

  LauncherService(this.rootPath, this.id);

  Future<WorkspaceProcess> spawn(
      String commandLine, WorkspaceOptions options) async {
    final launcherPath = await _findBinary();

    final args = _buildArgs(options, commandLine);

    final process = await Process.start(
      launcherPath,
      args,
      mode: ProcessStartMode.normal,
    );

    return NativeProcessImpl(process, timeout: options.timeout);
  }

  List<String> _buildArgs(WorkspaceOptions opts, String cmd) {
    final args = ['--id', id, '--workspace', rootPath];

    if (opts.sandbox) args.add('--sandbox');
    if (!opts.allowNetwork) args.add('--no-net');

    if (opts.workingDirectoryOverride != null) {
      final absCwd = p.join(rootPath, opts.workingDirectoryOverride!);
      args.addAll(['--cwd', absCwd]);
    }

    // Env vars logic...
    final env = <String, String>{};
    if (opts.includeParentEnv) env.addAll(Platform.environment);
    env.addAll(opts.env);
    env.forEach((k, v) => args.addAll(['--env', '$k=$v']));

    args.add('--');
    args.addAll(cmd.trim().split(RegExp(r'\s+')));

    return args;
  }

  Future<String> _findBinary() async {
    String osFolder;
    String binName = 'workspace_launcher';

    if (Platform.isWindows) {
      osFolder = 'windows';
      binName = '$binName.exe';
    } else if (Platform.isLinux) {
      osFolder = 'linux';
    } else if (Platform.isMacOS) {
      osFolder = 'macos';
    } else {
      throw UnsupportedError('Unsupported OS: ${Platform.operatingSystem}');
    }

    final locations = [
      p.join(Directory.current.path, 'bin', osFolder, 'x64', binName),
      p.join(Directory.current.path, 'native', 'target', 'release', binName),
    ];

    for (final loc in locations) {
      if (await File(loc).exists()) return loc;
    }

    throw Exception('Launcher binary not found. Checked: $locations');
  }
}
