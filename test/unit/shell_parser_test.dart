import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/src/util/shell_parser.dart';

void main() {
  group('ShellParser.prepareCommand', () {
    test('Should throw specific error on empty or whitespace-only commands',
        () {
      final invalidInputs = ['', '   ', '\t', '\n'];
      for (final input in invalidInputs) {
        expect(
          () => ShellParser.prepareCommand(input),
          throwsA(isA<Exception>()),
          reason: 'Should reject input: "$input"',
        );
      }
    });

    group('Platform: Linux/MacOS', () {
      test('Should return command trimmed but unchanged', () {
        if (Platform.isWindows) return;

        final inputs = {
          'echo hello': 'echo hello',
          '  ls -la  ': 'ls -la',
          './script.sh': './script.sh',
        };

        inputs.forEach((input, expected) {
          expect(ShellParser.prepareCommand(input), equals(expected));
        });
      });
    });

    group('Platform: Windows', () {
      test('Should wrap standard commands with cmd.exe /c', () {
        if (!Platform.isWindows) return;

        final cmd = 'echo hello';
        final result = ShellParser.prepareCommand(cmd);

        // Verify structure, ensuring cmd.exe invocation
        expect(result, startsWith('cmd.exe'));
        expect(result, contains('/c'));
        expect(result, contains('"echo hello"'));
      });

      test('Should handle commands with pipes and redirects', () {
        if (!Platform.isWindows) return;

        final complexCmd = 'dir | find "txt" > output.log';
        final result = ShellParser.prepareCommand(complexCmd);

        expect(result, contains('"dir | find "txt" > output.log"'));
      });

      test(
          'Should NOT wrap commands that are already calling cmd or powershell',
          () {
        if (!Platform.isWindows) return;

        final explicitCmds = [
          'cmd.exe /c start',
          'powershell -Command "ls"',
          'wsl ls'
        ];

        for (final cmd in explicitCmds) {
          expect(ShellParser.prepareCommand(cmd), equals(cmd),
              reason: 'Should execute explicit shell invoker directly');
        }
      });

      test('Should handle paths with spaces correctly', () {
        if (!Platform.isWindows) return;

        final cmd = '"C:\\Program Files\\Node\\node.exe" script.js';
        final result = ShellParser.prepareCommand(cmd);

        // Wrapping must preserve internal quotes
        expect(
            result, contains('"C:\\Program Files\\Node\\node.exe" script.js'));
      });
    });
  });
}
