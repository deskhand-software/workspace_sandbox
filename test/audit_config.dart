import 'dart:io';
import 'dart:math';
import 'package:audit_fuzz/auto_audit.dart';
import 'package:workspace_sandbox/workspace_sandbox.dart';

class WorkspaceOptionsGenerator implements FuzzGenerator<WorkspaceOptions> {
  @override
  WorkspaceOptions generate(Random random) => const WorkspaceOptions();
}

void main() {
  AutoAudit.runFromConfig((config) {
    config.iterations = 50;

    // 1. Registramos el generador
    config.addGenerator(WorkspaceOptionsGenerator());

    // 2. Registramos el objetivo (Un Workspace SEGURO)
    config.addTarget('SecureWorkspace', () {
      final tempDir = Directory.systemTemp.createTempSync('audit_sec_');
      // Creamos un workspace que NO debería permitir red (ajusta según tu API real)
      return Workspace.host(tempDir.path,
          options: const WorkspaceOptions(allowNetwork: false));
    });

    // 3. AÑADIMOS EL INVARIANTE DE SEGURIDAD
    config.addInvariant('No Network Access', (target, result) {
      // Si el método ejecutado fue 'run'
      if (result.methodName == 'run') {
        final cmd = result.positionalArgs.isNotEmpty
            ? result.positionalArgs.first.toString()
            : '';

        // Y el comando intentaba usar red (curl, wget, ping)
        if (cmd.contains('curl') ||
            cmd.contains('wget') ||
            cmd.contains('ping')) {
          // Y el resultado fue ÉXITO (no lanzó excepción)
          if (result.success) {
            throw "CRITICAL SECURITY FAIL: Network tool execution succeeded in restricted workspace! Cmd: $cmd";
          }
        }
      }
    });
  });
}
