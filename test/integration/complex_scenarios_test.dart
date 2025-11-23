import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() {
  group('Complex Integration Scenarios', () {
    late Workspace ws;

    setUp(() {
      ws = Workspace.secure(options: const WorkspaceOptions(sandbox: true));
    });

    tearDown(() async {
      await ws.dispose();
    });

    test('Full Stack API Build (Simulation)', () async {
      await ws.createDir('backend');
      final buildCmd = Platform.isWindows ? 'cmd /c ver' : 'uname';
      final res = await ws.run(buildCmd,
          options: const WorkspaceOptions(workingDirectoryOverride: 'backend'));

      // Solo verificar código de salida
      expect(res.exitCode, 0);
    });

    test('Native Script Execution', () async {
      final scriptName = Platform.isWindows ? 'run.bat' : 'run.sh';
      final outputName = 'output.txt';

      final scriptContent = Platform.isWindows
          ? '@echo off\necho DATA > $outputName'
          : '#!/bin/sh\necho "DATA" > $outputName';

      await ws.writeFile(scriptName, scriptContent);

      if (!Platform.isWindows) {
        await ws.run('chmod +x $scriptName');
      }

      final cmd = Platform.isWindows ? scriptName : './$scriptName';
      final result = await ws.run(cmd);

      // Si falla por "program not found", es porque Rust no está resolviendo el script local en PWD
      // Esto valida si la lógica de PWD en Rust funciona.
      expect(result.isSuccess, isTrue,
          reason: 'Script execution failed. Stderr: ${result.stderr}');

      if (result.isSuccess) {
        final outputFileContent = await ws.readFile(outputName);
        expect(outputFileContent.trim(), equals('DATA'));
      }
    });
  });
}
