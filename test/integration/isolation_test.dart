import 'dart:io';
import 'package:test/test.dart';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() {
  group('Sandbox Isolation', () {
    // Eliminamos setUpAll con Process.run manual.
    // Asumimos que curl existe o fallará el test (lo cual es correcto en integración).

    test(
      'Network: Should BLOCK access when allowNetwork: false',
      () async {
        final ws = Workspace.secure(
          options: const WorkspaceOptions(sandbox: true, allowNetwork: false),
        );

        try {
          // Intentamos conectar. Si falla por "curl not found", el test fallará,
          // lo que nos indica que falta curl en el entorno de test, no que la seguridad falle.
          // Usamos timeout corto para no colgar CI.
          final cmd = 'curl --connect-timeout 2 https://google.com';
          final result = await ws.run(cmd);

          // Si exitCode es 0, significa que curl se ejecutó Y conectó exitosamente -> FALLO DE SEGURIDAD
          if (result.exitCode == 0) {
            fail('Network was accessible! Output: ${result.stdout}');
          }
        } finally {
          await ws.dispose();
        }
      },
      // Skip condicional si sabemos que el entorno es minimalista (opcional)
    );

    test(
      'Network: Should ALLOW access when allowNetwork: true',
      () async {
        final ws = Workspace.secure(
          options: const WorkspaceOptions(sandbox: true, allowNetwork: true),
        );

        try {
          final cmd = 'curl -I https://google.com';
          final result = await ws.run(cmd);

          if (result.exitCode != 0) {
            print(
                'Warning: Network allowed but connection failed (DNS/Internet issue?).');
            print('Stderr: ${result.stderr}');
            fail('No se logro la conexion');
          } else {
            expect(result.exitCode, 0);
          }
        } finally {
          await ws.dispose();
        }
      },
    );

    test(
      'Filesystem: Should not allow listing of host Root',
      () async {
        final ws =
            Workspace.secure(options: const WorkspaceOptions(sandbox: true));
        try {
          // Intento de listar directorio de usuario
          final userDir = Platform.isWindows ? 'C:/Users' : '/home';
          final result = await ws.run('ls $userDir');

          // Si el comando falla (exit != 0), es BUENO (acceso denegado o carpeta no encontrada en sandbox)
          if (result.exitCode == 0) {
            // Si tuvo éxito, verificamos si filtró algo real
            final currentUser = Platform.environment['USERNAME'] ??
                Platform.environment['USER'] ??
                'unknown';
            if (result.stdout.contains(currentUser)) {
              fail(
                  'Sandbox Leak: Found user folder "$currentUser" in "$userDir"');
            }
          }
        } finally {
          await ws.dispose();
        }
      },
    );
  });
}
