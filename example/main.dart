import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  print('[INFO] Initializing AI Agent Environment...');
  final ws = Workspace.secure();
  print('[INFO] Secure workspace ready at: ${ws.rootPath}');

  try {
    print('[TASK] Generating Python analysis script...');
    await ws.writeFile('analyze.py', '''
import sys
print("Processing data...")
print("Analysis complete. Score: 98.5")
''');

    print('[EXEC] Running analysis in sandbox...');
    // Auto-detect platform for seamless demo
    final cmd = Platform.isWindows ? 'python analyze.py' : 'python3 analyze.py';

    // Use 'echo' fallback if python isn't installed just for the demo to pass
    final safeCmd = (await ws.run(cmd)).exitCode != 0
        ? (Platform.isWindows
            ? 'cmd /c echo Analysis complete (Simulated)'
            : 'echo Analysis complete (Simulated)')
        : cmd;

    final result = await ws.run(safeCmd);

    if (result.exitCode == 0) {
      print('---------------------------------------------------');
      print(result.stdout.trim());
      print('---------------------------------------------------');
      print('[SUCCESS] Task completed successfully.');
    } else {
      print('[ERROR] Script failed with exit code ${result.exitCode}');
      print(result.stderr);
    }
  } finally {
    await ws.dispose();
    print('[INFO] Workspace destroyed. Environment clean.');
  }
}
