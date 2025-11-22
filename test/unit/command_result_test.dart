import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() {
  group('CommandResult Model', () {
    test('isSuccess/isFailure logic', () {
      final success = CommandResult(
        exitCode: 0,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
      );
      final failure = CommandResult(
        exitCode: 1,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
      );
      final signalKill = CommandResult(
        exitCode: -1,
        stdout: '',
        stderr: '',
        duration: Duration.zero,
      );

      expect(success.isSuccess, isTrue);
      expect(success.isFailure, isFalse);

      expect(failure.isSuccess, isFalse);
      expect(failure.isFailure, isTrue);

      expect(signalKill.isSuccess, isFalse);
      expect(signalKill.isFailure, isTrue);
    });

    test('ToString formatting for logging', () {
      final res = CommandResult(
        exitCode: 127,
        stdout: 'output',
        stderr: 'error msg',
        duration: const Duration(milliseconds: 500),
      );

      final log = res.toString();
      expect(log, contains('exitCode: 127'));
      expect(log, contains('500ms'));
    });

    test('Should handle null-like empty outputs gracefully', () {
      final res = CommandResult(
          exitCode: 0, stdout: '', stderr: '', duration: Duration.zero);
      expect(res.stdout, isEmpty);
      expect(res.stderr, isEmpty);
    });
  });
}
