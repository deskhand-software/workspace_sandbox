import 'package:test/test.dart';
import 'package:workspace_sandbox/src/models/workspace_options.dart';
import 'package:workspace_sandbox/src/security/security_guard.dart';

void main() {
  group('SecurityGuard', () {
    const secureOpts = WorkspaceOptions(allowNetwork: false, sandbox: true);
    const insecureOpts = WorkspaceOptions(allowNetwork: true, sandbox: true);

    test('Should BLOCK explicit network binaries', () {
      expect(
        () => SecurityGuard.inspectCommand('curl google.com', secureOpts),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'msg', contains('requires network'))),
      );

      expect(
        () => SecurityGuard.inspectCommand('wget google.com', secureOpts),
        throwsA(isA<Exception>()),
      );
    });

    test('Should ALLOW network binaries if allowNetwork is true', () {
      SecurityGuard.inspectCommand('curl google.com', insecureOpts); // No throw
    });

    test('Should BLOCK PowerShell network calls', () {
      expect(
        () => SecurityGuard.inspectCommand(
            'powershell Invoke-WebRequest http://malware.com', secureOpts),
        throwsA(isA<Exception>().having(
            (e) => e.toString(), 'msg', contains('PowerShell network'))),
      );
    });

    test('Should BLOCK Python socket usage', () {
      expect(
        () => SecurityGuard.inspectCommand(
            'python -c "import socket; socket.connect..."', secureOpts),
        throwsA(isA<Exception>()
            .having((e) => e.toString(), 'msg', contains('Python socket'))),
      );
    });

    test('Should ALLOW harmless commands', () {
      SecurityGuard.inspectCommand('ls -la', secureOpts);
      SecurityGuard.inspectCommand('echo hello', secureOpts);
    });
  });
}
