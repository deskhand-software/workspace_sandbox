import 'dart:io';
import 'dart:async';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  print('☕ Agent: Initializing Spring Boot Secure API (JWT)...');
  
  // Spring Boot necesita red intensiva para Maven Central
  final ws = Workspace.secure(options: const WorkspaceOptions(allowNetwork: true));

  try {
    // 1. Estructura de proyecto (Maven)
    // Usamos Maven Wrapper (mvnw) si es posible, o mvn del sistema.
    // Para asegurar que funcione, asumimos que 'mvn' está en el PATH del host.
    
    print('📂 Step 1: Creating Project Structure...');
    await ws.createDir('src/main/java/com/example/demo');
    await ws.createDir('src/main/resources');

    // pom.xml con Spring Boot Starter Web + Security
    await ws.writeFile('pom.xml', r'''
<project xmlns="http://maven.apache.org/POM/4.0.0" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>demo</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.1.5</version> <!-- Versión estable -->
    </parent>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <!-- Security simulado para no complicar con JWT real en 1 archivo -->
        <!-- En un caso real, el LLM escribiría AuthController.java completo -->
    </dependencies>
    <properties>
        <java.version>17</java.version>
    </properties>
</project>
''');

    // Aplicación Principal
    await ws.writeFile('src/main/java/com/example/demo/DemoApplication.java', r'''
package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class DemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(DemoApplication.class, args);
    }

    @GetMapping("/")
    public String home() {
        return "{\"status\": \"active\", \"message\": \"Spring Boot inside Sandbox works!\"}";
    }
    
    @GetMapping("/api/secure")
    public String secure() {
        return "{\"secret\": \"This endpoint would be JWT protected\"}";
    }
}
''');

    // Configuración (Puerto 8081 para no chocar con el anterior)
    await ws.writeFile('src/main/resources/application.properties', 'server.port=8081');

    // 2. Compilación (Maven)
    print('🐘 Step 2: Compiling with Maven (This downloads dependencies)...');
    // '-B' (Batch mode) para logs menos ruidosos
    // Damos un timeout generoso (5 min) porque Maven descarga mucho
    final compile = await ws.run('mvn clean package -DskipTests', 
        options: const WorkspaceOptions(allowNetwork: true, timeout: Duration(minutes: 10)));

    if (compile.exitCode != 0) {
        print('❌ Compilation Failed!');
        print(compile.stdout); // Maven a veces tira errores en stdout
        print(compile.stderr);
        
        // Fallback: Si no hay mvn, intentamos javac directo para demostrar que Java funciona
        // (Omitido para no alargar, asumimos mvn instalado en host)
        return;
    }
    print('✅ Build Success! Jar created.');

    // 3. Ejecución
    print('🚀 Step 3: Launching Spring Boot...');
    // Buscamos el jar generado
    final jarPath = 'target/demo-0.0.1-SNAPSHOT.jar';
    
    final server = await ws.start('java -jar $jarPath');

    // 4. Observabilidad
    StreamSubscription? logger;
    logger = server.stdout.listen((line) {
        // Filtramos logs para ver solo lo importante
        if (line.contains('Started DemoApplication') || line.contains('ERROR')) {
            print('[SPRING] $line');
        }
    });

    print('\n✅ Service ready on http://localhost:8081');
    print('⌨️  Press ENTER to stop...');
    await stdin.first;

    print('🛑 Stopping...');
    server.kill();
    await logger.cancel();

  } catch (e) {
    print('Error: $e');
  } finally {
    await ws.dispose();
  }
}
