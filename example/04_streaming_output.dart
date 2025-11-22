import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  final ws = Workspace.secure();
  print('--- Real-time Build Process Log ---');

  // Create a mock build script
  if (Platform.isWindows) {
    await ws.writeFile('build.bat', '''
@echo off
echo [10:00:01] Initializing build system...
ping 127.0.0.1 -n 2 > nul
echo [10:00:02] Compiling core modules...
ping 127.0.0.1 -n 2 > nul
echo [10:00:03] Linking binaries...
ping 127.0.0.1 -n 2 > nul
echo [10:00:04] Build SUCCESS. Artifacts generated.
''');
  } else {
    await ws.writeFile('build.sh', '''
#!/bin/sh
echo "[10:00:01] Initializing build system..."
sleep 1
echo "[10:00:02] Compiling core modules..."
sleep 1
echo "[10:00:03] Linking binaries..."
sleep 1
echo "[10:00:04] Build SUCCESS. Artifacts generated."
''');
    await ws.run('chmod +x build.sh');
  }

  final cmd = Platform.isWindows ? 'build.bat' : './build.sh';
  final process = await ws.start(cmd);

  // Stream output with prefix to distinguish source
  process.stdout.listen((line) {
    if (line.isNotEmpty) print('BUILD >> $line');
  });

  process.stderr.listen((line) {
    if (line.isNotEmpty) print('ERROR >> $line');
  });

  final exitCode = await process.exitCode;
  print('--- Process terminated with code $exitCode ---');

  await ws.dispose();
}
