import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  final ws = Workspace.secure();
  print('--- Watchdog Timeout Demo ---');
  print('Policy: Processes exceeding 2 seconds will be terminated.');

  // Simulate a hung process (infinite loop or wait)
  final cmd =
      Platform.isWindows ? 'cmd /c "ping -t 127.0.0.1 > nul"' : 'sleep 20';

  print('Status: Executing job...');
  final stopwatch = Stopwatch()..start();

  final result = await ws.run(
    cmd,
    options: const WorkspaceOptions(timeout: Duration(seconds: 2)),
  );

  stopwatch.stop();
  final elapsed = stopwatch.elapsed.inMilliseconds;

  print('\n--- Execution Report ---');
  print('Time elapsed: ${elapsed}ms');
  print('Timeout limit: 2000ms');

  if (result.isCancelled) {
    print('Termination: ENFORCED (Watchdog killed the process)');
  } else {
    print('Termination: NATURAL (Process finished normally)');
  }

  await ws.dispose();
}
