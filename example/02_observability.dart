import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  print('--- Observability Tools Demo ---');
  final ws = Workspace.secure();

  // Simulate a fetched Git repository structure
  await ws.createDir('src/services');
  await ws.createDir('tests');
  await ws.writeFile('src/main.dart', '// Entry point');
  await ws.writeFile('src/services/auth.dart', '// TODO: Implement OAuth2');
  await ws.writeFile('src/services/db.dart', '// FIXME: Connection leak');
  await ws.writeFile('tests/auth_test.dart', 'void main() {}');
  await ws.writeFile('README.md', '# Backend API\n\nDo not commit secrets!');

  print('\n[Tree View] Visualizing project structure:');
  // Use maxDepth to limit token usage in LLM scenarios
  final tree = await ws.tree(maxDepth: 3);
  print(tree.trim());

  print('\n[Grep] Scanning for technical debt (TODO/FIXME):');
  final todos = await ws.grep('TODO');
  final fixmes = await ws.grep('FIXME');

  if (todos.isNotEmpty) print(todos.trim());
  if (fixmes.isNotEmpty) print(fixmes.trim());

  print('\n[Find] Locating all test files:');
  final tests = await ws.find('*_test.dart');
  tests.forEach((f) => print('  Found: $f'));

  await ws.dispose();
}
