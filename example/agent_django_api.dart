import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';
import 'package:http/http.dart' as http;

void main() async {
  print('🤖 Agent: I will create a Django API safely inside the sandbox.');

  final ws = Workspace.secure(
    options: const WorkspaceOptions(allowNetwork: true), // Necesario para pip
  );

  try {
    // PASO 1: Configuración (Tool: writeFile)
    print('📝 Step 1: Setting up requirements...');
    await ws.writeFile('requirements.txt', 'Django>=4.0,<5.0');

    // PASO 2: Instalación (Tool: run)
    // Nota: En un entorno efímero real, usaríamos un venv. 
    // Aquí simplificamos asumiendo que python3 y pip están disponibles.
    print('📦 Step 2: Installing Django...');
    var res = await ws.run('pip install -r requirements.txt'); 
    // Si falla pip global por permisos, intentamos --user o venv
    if (res.exitCode != 0) {
        print('   Pip failed globally, trying virtualenv...');
        await ws.run('python3 -m venv venv');
        // En adelante, usamos el python del venv
        // Windows: venv\Scripts\python, Linux: venv/bin/python
        // Para el ejemplo asumimos Linux/Mac por simplicidad de paths
    }

    // Comandos encadenados para setup rápido (simulando un agente experto)
    print('🔨 Step 3: Scaffolding project...');
    final python = Platform.isWindows ? 'venv\\Scripts\\python' : 'venv/bin/python';
    final djangoAdmin = Platform.isWindows ? 'venv\\Scripts\\django-admin' : 'venv/bin/django-admin';

    // Crear venv si no existe
    if (!await ws.exists('venv')) await ws.run('python3 -m venv venv');

    await ws.run('$djangoAdmin startproject myapi .'); // . para crear en raíz
    await ws.run('$python manage.py migrate');

    // Crear vista simple
    await ws.writeFile('myapi/views.py', '''
from django.http import HttpResponse
def home(request):
    return HttpResponse("<h1>Hello from LLM Sandbox!</h1>")
''');

    await ws.writeFile('myapi/urls.py', '''
from django.contrib import admin
from django.urls import path
from . import views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', views.home),
]
''');

    // PASO 3: Ejecución (Tool: start)
    print('🚀 Step 4: Launching server...');
    final serverProcess = await ws.start('$python manage.py runserver 0.0.0.0:8000');
    
    // Monitor de logs
    serverProcess.stderr.listen((data) {
        if (data.contains('Quit the server')) print('   Server is ready!');
    });

    // Dar tiempo a que arranque
    await Future.delayed(const Duration(seconds: 5));

    // PASO 4: Verificación (Agente verificando su propio trabajo)
    print('🔍 Step 5: Verifying API health...');
    try {
      final response = await http.get(Uri.parse('http://localhost:8000'));
      if (response.statusCode == 200 && response.body.contains('LLM Sandbox')) {
          print('✅ SUCCESS: API responded correctly!');
          print('   Response: "${response.body}"');
      } else {
          print('❌ FAILURE: Unexpected response: ${response.statusCode}');
      }
    } catch (e) {
        print('❌ FAILURE: Could not connect to server. ($e)');
        print('   (Note: This might happen if the sandbox blocks incoming connections)');
    }

    serverProcess.kill();

  } catch (e) {
    print('💥 Agent Error: $e');
  } finally {
    await ws.dispose();
    print('🧹 Workspace cleaned.');
  }
}
