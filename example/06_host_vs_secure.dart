import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  print('--- Comparison: Host vs Secure Workspace ---');

  // Case A: Persistent Project (e.g., opening a user folder)
  final tempDir = Directory.systemTemp.createTempSync('my_project_');
  print('\n[Case A] Persistent Workspace');
  print('Target: ${tempDir.path}');

  final hostWs = Workspace.host(tempDir.path);
  await hostWs.writeFile('notes.txt', 'Meeting notes: Discuss Q4 goals.');
  await hostWs.dispose(); // Does not delete files

  if (File('${tempDir.path}/notes.txt').existsSync()) {
    print(
        'Result: Files PERSISTED after dispose(). (Correct for project editing)');
  }

  // Cleanup manually for demo
  tempDir.deleteSync(recursive: true);

  // Case B: Disposable Agent Environment
  print('\n[Case B] Secure Ephemeral Workspace');
  final secureWs = Workspace.secure();
  print('Target: ${secureWs.rootPath}');

  await secureWs.writeFile('secret.key', 'xyz-123-abc');
  final path = secureWs.rootPath;

  await secureWs.dispose(); // Deletes everything

  if (!Directory(path).existsSync()) {
    print(
        'Result: Files VANISHED after dispose(). (Correct for secure agents)');
  }
}
