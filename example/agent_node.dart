import 'dart:io';
import 'dart:async'; // Necesario para StreamSubscription
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  print('🤖 Agent: Setting up interactive Next.js server.');
  
  // allowNetwork: true es vital para descargar paquetes Y para que el servidor sea accesible
  final ws = Workspace.secure(options: const WorkspaceOptions(allowNetwork: true));

  try {
    // ... (Pasos de creación de package.json igual que antes) ...
    await ws.writeFile('package.json', '''
{
  "name": "demo-app",
  "scripts": {
    "dev": "python3 -m http.server 8080" 
  }
}
'''); 
// NOTA: Uso python http.server para simular porque no tienes node nuevo, 
// pero la lógica es idéntica para 'next dev' o 'python manage.py runserver 0.0.0.0:8000'.
// Simplemente asegúrate de que el comando escuche en 0.0.0.0

    await ws.writeFile('index.html', '<h1>Hello from Sandbox!</h1>');

    // --- FASE DE EJECUCIÓN INTERACTIVA ---
    
    print('🚀 Starting server on port 8080...');
    
    // Usamos start(), NO run(), para no bloquearnos esperando que termine (porque un servidor no termina)
    final serverProcess = await ws.start('npm run dev'); 

    // 1. VER ERRORES EN TIEMPO REAL (Lo que pedías)
    // Conectamos los cables: Lo que escupe el proceso -> Lo imprimimos en tu consola
    // Un LLM usaría esto para leer el contexto y decir "Ah, falta una migración".
    
    StreamSubscription? outSub;
    StreamSubscription? errSub;

    outSub = serverProcess.stdout.listen((line) {
        stdout.write('[SERVER] $line'); // Usamos stdout.write para no meter saltos de linea extra
    });

    errSub = serverProcess.stderr.listen((line) {
        stderr.write('🚨 [ERROR] $line'); // Rojo o marcado para que destaque
        
        // AQUÍ el LLM detectaría patrones de error
        if (line.contains('Address already in use')) {
             print('\n🤖 Agent: Port conflict detected! I should try port 8081.');
        }
    });

    // 2. MANTENER VIVO (Persistencia)
    print('\n✅ Server is running inside sandbox.');
    print('🌍 Try accessing: http://localhost:8080 (or 127.0.0.1:8080)');
    print('⌨️  Press ENTER to stop the server and cleanup...');
    
    // Bloqueamos el script de Dart aquí hasta que el usuario (tú) decida terminar.
    await stdin.first;

    print('🛑 Stopping server...');
    serverProcess.kill();
    
    // Esperamos limpieza de streams
    await outSub.cancel();
    await errSub.cancel();

  } catch (e) {
    print('Fatal Error: $e');
  } finally {
    print('🧹 Disposing workspace...');
    await ws.dispose();
    print('👋 Bye!');
  }
}
