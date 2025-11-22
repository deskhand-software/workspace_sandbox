import 'package:test/test.dart';
import 'package:workspace_sandbox/src/models/workspace_options.dart';
import 'package:workspace_sandbox/src/security/security_guard.dart';

void main() {
  group('SecurityGuard (Static Analysis)', () {
    const secureOpts = WorkspaceOptions(allowNetwork: false, sandbox: true);
    const insecureOpts = WorkspaceOptions(allowNetwork: true, sandbox: true);

    group('Network Blocking Rules', () {
      test('Should BLOCK standard network binaries', () {
        final binaries = ['curl', 'wget', 'ssh', 'nc'];
        for (final bin in binaries) {
          expect(
            () => SecurityGuard.inspectCommand('$bin google.com', secureOpts),
            throwsA(isA<Exception>().having((e) => e.toString(), 'message',
                contains('requires network access'))),
          );
        }
      });

      test('Should BLOCK obfuscated commands (Case Insensitivity)', () {
        // PowerShell only blocks if malicious keywords are found
        final cmd = 'PoWeRsHeLl -Command "New-Object Net.Sockets.TcpClient"';
        expect(
          () => SecurityGuard.inspectCommand(cmd, secureOpts),
          throwsA(isA<Exception>()),
          reason: 'Should block mixed-case malicious PowerShell',
        );
      });

      test('Should BLOCK Python socket usage', () {
        final payload = 'python -c "import socket; s=socket.socket()"';
        expect(
          () => SecurityGuard.inspectCommand(payload, secureOpts),
          throwsA(isA<Exception>().having(
              (e) => e.toString(),
              'message',
              // Updated to match your actual implementation message
              contains('Python network library usage'))),
        );
      });

      test('Should BLOCK Node.js network usage', () {
        final payload = 'node -e "require(\'net\').connect()"';
        expect(
          () => SecurityGuard.inspectCommand(payload, secureOpts),
          throwsA(isA<Exception>().having(
              (e) => e.toString(), 'message', contains('Node.js network'))),
        );
      });

      test('Should ALLOW network tools if allowNetwork is true', () {
        SecurityGuard.inspectCommand('curl google.com', insecureOpts);
      });
    });
  });
}
