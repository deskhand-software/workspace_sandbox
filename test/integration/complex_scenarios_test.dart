import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() {
  group('Complex Integration Scenarios', () {
    late Workspace ws;

    setUp(() {
      ws = Workspace.ephemeral();
    });

    tearDown(() async {
      await ws.dispose();
    });

    test('Full Stack API Build Simulation', () async {
      await ws.fs.createDir('backend');
      final buildCmd = Platform.isWindows ? 'cmd /c ver' : 'uname';
      final res = await ws.exec(buildCmd,
          options: const WorkspaceOptions(workingDirectoryOverride: 'backend'));
      expect(res.exitCode, 0);
    });

    test('Native Script Execution', () async {
      final scriptName = Platform.isWindows ? 'run.bat' : 'run.sh';
      final outputName = 'output.txt';

      final scriptContent = Platform.isWindows
          ? '@echo off\necho DATA > $outputName'
          : '#!/bin/sh\necho "DATA" > $outputName';

      await ws.fs.writeFile(scriptName, scriptContent);

      if (!Platform.isWindows) {
        await ws.exec('chmod +x $scriptName');
      }

      final cmd = Platform.isWindows ? scriptName : './$scriptName';
      final result = await ws.exec(cmd);

      expect(result.isSuccess, isTrue);

      if (result.isSuccess) {
        final outputFileContent = await ws.fs.readFile(outputName);
        expect(outputFileContent.trim(), equals('DATA'));
      }
    });
  });
}
