import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  print('--- Workspace Sandbox: Basic Lifecycle Demo ---');

  // 1. Create
  final ws = Workspace.secure();
  print('[1/4] Workspace created.');
  print('      Path: ${ws.rootPath}');

  // 2. Populate
  print('[2/4] Populating workspace assets...');
  await ws.writeFile('config.json', '{"env": "production", "retries": 3}');
  await ws.createDir('logs');

  // 3. Verify
  final configExists = await ws.exists('config.json');
  final fileSize = (await ws.readFile('config.json')).length;
  print('      config.json created: $configExists ($fileSize bytes)');

  // 4. Execute
  print('[3/4] Listing directory contents (ls -R)...');
  final cmd = Platform.isWindows ? 'cmd /c dir /S /B' : 'ls -R';
  final result = await ws.run(cmd);

  print('      Output:\n${result.stdout.trim()}');

  // 5. Cleanup
  await ws.dispose();
  print('[4/4] Workspace disposed. All resources released.');
}
