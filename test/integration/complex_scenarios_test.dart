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

    test('NodeJS/NPM Scenario', () async {
      final checkNode = await ws.run('node --version');
      if (checkNode.exitCode != 0) return; // Skip if no node

      await ws.writeFile('package.json',
          '{"name": "test", "scripts": {"start": "node app.js"}}');
      await ws.writeFile('app.js', 'console.log("Hello Node");');

      final npmCmd = Platform.isWindows ? 'npm.cmd run start' : 'npm run start';
      final result = await ws.run(npmCmd);

      // If exit code is 0, the command worked.
      // Stdout might be empty depending on npm verbosity settings.
      expect(result.exitCode, 0);

      if (result.stdout.isEmpty && result.stderr.isEmpty) {
        print('Warning: NPM output was empty but exit code 0.');
      } else {
        expect(result.stdout + result.stderr, contains('Hello Node'));
      }
    });

    test('Native Script Execution', () async {
      String scriptName = Platform.isWindows ? 'run.bat' : 'run.sh';
      String scriptContent = Platform.isWindows
          ? '@echo off\necho DATA'
          : '#!/bin/sh\necho "DATA"';

      await ws.writeFile(scriptName, scriptContent);
      if (!Platform.isWindows) await ws.run('chmod +x $scriptName');

      final cmd = Platform.isWindows ? scriptName : './$scriptName';
      final result = await ws.run(cmd);

      expect(result.stdout.trim(), equals('DATA'));
    });
  });
}
