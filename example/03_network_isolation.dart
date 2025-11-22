import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  print('--- Security Audit: Network Isolation ---');

  // SCENARIO 1: Malware attempting to phone home
  print('\n[Scenario 1] Sandbox with Network BLOCKED');
  final secureWs = Workspace.secure(
    options: const WorkspaceOptions(sandbox: true, allowNetwork: false),
  );

  final target = 'google.com';
  print('  Action: Attempting to reach $target...');

  final cmd = Platform.isWindows ? 'ping -n 1 $target' : 'ping -c 1 $target';

  final blockResult = await secureWs.run(cmd,
      options: const WorkspaceOptions(timeout: Duration(seconds: 3)));

  if (blockResult.exitCode != 0) {
    print('  Result: BLOCKED (Exit Code: ${blockResult.exitCode})');
    print('  Status: PASS (Data exfiltration prevented)');
  } else {
    print('  Result: CONNECTED');
    print('  Status: FAIL (Network was accessible)');
  }
  await secureWs.dispose();

  // SCENARIO 2: Authorized tool updating dependencies
  print('\n[Scenario 2] Sandbox with Network ALLOWED');
  final openWs = Workspace.secure(
    options: const WorkspaceOptions(sandbox: true, allowNetwork: true),
  );

  print('  Action: Verifying connectivity (Localhost)...');
  final allowResult = await openWs
      .run(Platform.isWindows ? 'ping -n 1 127.0.0.1' : 'ping -c 1 127.0.0.1');

  if (allowResult.exitCode == 0) {
    print('  Result: CONNECTED');
    print('  Status: PASS (Legitimate traffic allowed)');
  } else {
    print('  Result: FAILED');
    print('  Status: WARN (Check internet connection)');
  }
  await openWs.dispose();
}
