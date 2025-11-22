import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() {
  group('Sandbox Isolation', () {
    test('Network: Should BLOCK access when allowNetwork: false', () async {
      final ws = Workspace.secure(
        options: const WorkspaceOptions(sandbox: true, allowNetwork: false),
      );

      try {
        final cmd = Platform.isWindows
            ? 'curl --connect-timeout 2 https://google.com'
            : 'curl --connect-timeout 2 https://google.com';

        final result = await ws.run(cmd);

        // Curl exit code != 0 implies failure (good)
        if (result.exitCode == 0) {
          fail('Network was accessible! Output: ${result.stdout}');
        }
      } finally {
        await ws.dispose();
      }
    });

    test('Network: Should ALLOW access when allowNetwork: true', () async {
      final ws = Workspace.secure(
        options: const WorkspaceOptions(sandbox: true, allowNetwork: true),
      );

      try {
        final cmd = Platform.isWindows
            ? 'curl -I https://google.com'
            : 'curl -I https://google.com';

        final result = await ws.run(cmd);

        if (result.exitCode != 0) {
          print(
              'Warning: Network allowed but connection failed (DNS/Internet issues?)');
          print(result.stderr);
          return; // Don't fail test if host has no internet
        }
        expect(result.exitCode, 0);
      } finally {
        await ws.dispose();
      }
    });

    test('Filesystem: Should not allow listing of host Root', () async {
      if (Platform.isWindows) return;

      final ws =
          Workspace.secure(options: const WorkspaceOptions(sandbox: true));
      try {
        // In Bubblewrap with empty root, /home shouldn't exist or be empty
        // unless explicitly mounted.
        final result = await ws.run('ls /home');
        // We assume the user running the test has a /home folder.
        // If the sandbox works, we shouldn't see the user's folder.

        final currentUser = Platform.environment['USER'] ?? 'unknown';
        if (result.stdout.contains(currentUser)) {
          fail('Sandbox Leak: Found current user folder in /home');
        }
      } finally {
        await ws.dispose();
      }
    });
  });
}
