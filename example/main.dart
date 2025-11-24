import 'package:workspace_sandbox/workspace_sandbox.dart';

/// Demonstrates basic workspace operations.
///
/// This example shows how to:
/// - Create an ephemeral workspace
/// - Write and read files
/// - Execute shell commands with pipes
/// - Execute binaries directly (safe, no shell interpretation)
/// - Use filesystem helpers (tree, find, etc.)
/// - Read command results and outputs
void main() async {
  final ws = Workspace.ephemeral();

  try {
    print('Workspace created at: ${ws.rootPath}');

    print('\nStep 1: Creating a file...');
    // Write file using the filesystem service
    await ws.fs.writeFile('hello.txt', 'Hello from Sandbox!');

    print('Step 2: Running a shell command...');
    // Run a shell command (String executes in shell, allows pipes/redirection)
    final shellResult = await ws.exec('grep "Hello" hello.txt');

    if (shellResult.exitCode == 0) {
      print('Shell command succeeded: ${shellResult.stdout.trim()}');
    } else {
      print('Shell command failed: ${shellResult.stderr}');
    }

    print('\nStep 3: Listing workspace files...');
    // Find files via glob pattern (filesystem helper)
    final dartFiles = await ws.fs.find('*.txt');
    print('Text files in workspace: $dartFiles');

    print('\nStep 4: Showing workspace tree...');
    final tree = await ws.fs.tree();
    print(tree);

    print('\nStep 5: Executing binary directly (safe)');
    // Run a binary via argument list (no shell features, injection-proof)
    final binResult = await ws.exec(['cat', 'hello.txt']);
    print('Binary execution output: ${binResult.stdout.trim()}');

    print('\nStep 6: Reading file...');
    final helloContent = await ws.fs.readFile('hello.txt');
    print('Read file content: "$helloContent"');
  } finally {
    await ws.dispose();
    print('\nWorkspace cleaned up.');
  }
}
