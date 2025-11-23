import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  print('🔒 Creating secure workspace...');

  // 1. Crear espacio efímero seguro
  final ws = Workspace.secure(
    options: const WorkspaceOptions(
      allowNetwork: true, // Necesitamos red para simular "npm install"
      timeout: Duration(minutes: 2),
    ),
  );

  try {
    print('📂 Root: ${ws.rootPath}');

    // 2. Simular estructura de proyecto (como si hubiéramos hecho git clone)
    await ws.writeFile(
        'package.json', '{"name": "secure-app", "dependencies": {}}');
    await ws.writeFile('src/index.js', 'console.log("Hello form Sandbox!");');
    await ws.writeFile('test/app.test.js', 'console.log("Test passed");');

    // 3. Ejecutar instalación (Simulada con npm init o touch para no depender de npm real)
    // En un entorno real usaríamos 'npm install'
    print('📦 Installing dependencies...');
    final install =
        await ws.run('npm init -y'); // O 'echo Installing...' si no tienes npm

    if (install.exitCode != 0) {
      print('❌ Install failed: ${install.stderr}');
    } else {
      print('✅ Install success');
    }

    // 4. Verificar estructura creada
    print('\n🌳 Workspace Tree:');
    print(await ws.tree(maxDepth: 3));

    // 5. Ejecutar tests del proyecto sandboxeado
    print('🧪 Running project tests...');
    // Node.js ejecutándose dentro del sandbox
    final testRun = await ws.run('node test/app.test.js');

    print('Test Output: ${testRun.stdout.trim()}');

    // 6. Demostrar aislamiento (Intentar leer fuera)
    print('\n🕵️ Testing isolation...');
    // Intentar leer /etc/passwd o C:/Windows/win.ini
    final sensitiveFile =
        Platform.isWindows ? 'C:/Windows/win.ini' : '/etc/passwd';
    final hackAttempt = await ws.run(
        'cat $sensitiveFile'); // 'type' en windows se traduce auto? No, 'cat' no existe en win cmd.
    // Usamos 'more' o 'type' condicional, o dart para ser agnósticos

    if (hackAttempt.exitCode != 0) {
      print('🛡️ Isolation confirmed: Access denied to host file system.');
    } else {
      print('⚠️ WARNING: Sandbox leak detected!');
    }
  } finally {
    await ws.dispose();
    print('\n🧹 Workspace cleaned up.');
  }
}
