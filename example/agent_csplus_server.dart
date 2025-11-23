import 'dart:async';
import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  print('🤖 Agent: Building a high-performance C++ Controller.');
  
  // Necesitamos red si quisiéramos bajar librerías, pero para g++ local no es estricto.
  // Lo ponemos true para simular un entorno real.
  final ws = Workspace.secure(options: const WorkspaceOptions(allowNetwork: true));

  try {
    // 1. Escribir código C++ Complejo
    // Simula un servidor que tiene un "memory leak" o fallo crítico eventual
    await ws.writeFile('controller.cpp', r'''
#include <iostream>
#include <thread>
#include <chrono>
#include <vector>

void simulate_work(int step) {
    std::cout << "[INFO] Processing batch " << step << "..." << std::endl;
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    
    if (step == 3) {
        std::cerr << "[WARN] High memory usage detected!" << std::endl;
    }
    
    if (step == 5) {
        std::cerr << "[CRITICAL] Segmentation Fault (Simulated)" << std::endl;
        exit(139); // Simular crash
    }
}

int main() {
    std::cout << "--- C++ Controller v1.0 Started ---" << std::endl;
    std::cout << "Listening on port 8080 (Simulated)" << std::endl;
    
    for (int i = 1; i <= 10; ++i) {
        simulate_work(i);
    }
    
    return 0;
}
''');

    // 2. Compilar (Tool: run)
    print('🔨 Compiling C++ binary...');
    // Intentamos g++ (Linux/WSL/Mac) o cl.exe (Windows si tienes VS tools en PATH)
    // Asumiremos g++ para el ejemplo multiplataforma (MinGW en Win).
    final compile = await ws.run('g++ controller.cpp -o controller');
    
    if (compile.exitCode != 0) {
        print('❌ Compilation failed:');
        print(compile.stderr);
        return;
    }
    print('✅ Compilation success.');

    // 3. Ejecución con STREAMING (Tool: start)
    // AQUI ESTÁ LA MAGIA: No esperamos a que termine. Escuchamos en vivo.
    print('🚀 Launching binary...');
    final process = await ws.start(Platform.isWindows ? 'controller.exe' : './controller');

    // Simulamos que somos el LLM leyendo la terminal en tiempo real
    final controller = StreamController<void>();

    process.stdout.listen((line) {
        print('   [STDOUT] $line'); // Feedback visual inmediato
    });

    process.stderr.listen((line) {
        print('   🚨 [STDERR] $line'); // El LLM detectaría esto inmediatamente
        
        if (line.contains('Segmentation Fault')) {
            print('\n🤖 Agent: Oops! I detected a crash. I should fix the code.');
            // Aquí el agente podría decidir reescribir el archivo y recompilar
        }
    });

    // Mantener vivo el script de Dart hasta que el proceso termine
    await process.exitCode.then((code) {
        print('\n🛑 Process finished with exit code: $code');
    });

  } catch (e) {
      print('Error: $e');
  } finally {
    await ws.dispose();
  }
}
