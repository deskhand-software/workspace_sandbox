import 'dart:io';
import 'package:workspace_sandbox/workspace_sandbox.dart';

void main() async {
  print('🤖 Agent: I will analyze data and generate a report.');
  final ws = Workspace.secure(); // No network needed for local analysis

  try {
    // PASO 1: Ingesta de Datos
    print('📥 Step 1: Receiving data...');
    await ws.writeFile('sales.csv', '''
product,amount
A,100
B,200
C,150
A,50
''');

    // PASO 2: Código de Análisis (Python)
    print('🐍 Step 2: Writing analysis script...');
    await ws.writeFile('analyze.py', '''
import csv

summary = {}
total = 0

with open('sales.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        prod = row['product']
        val = int(row['amount'])
        summary[prod] = summary.get(prod, 0) + val
        total += val

# Generate Report
with open('report.md', 'w') as f:
    f.write(f"# Sales Report\\n\\n")
    f.write(f"**Total Revenue:** \${total}\\n\\n")
    f.write("## Breakdown\\n")
    for p, v in summary.items():
        f.write(f"- **{p}**: \${v}\\n")

print("Analysis complete.")
''');

    // PASO 3: Ejecución
    print('⚙️ Step 3: Running analysis...');
    final run = await ws.run('python3 analyze.py');
    
    if (run.exitCode != 0) {
        print('❌ Analysis failed: ${run.stderr}');
        return;
    }
    print('   Output: ${run.stdout.trim()}');

    // PASO 4: Extracción de Resultados
    print('📤 Step 4: Retrieving report...');
    if (await ws.exists('report.md')) {
        final report = await ws.readFile('report.md');
        print('\n--- GENERATED REPORT ---');
        print(report);
        print('------------------------\n');
        print('✅ SUCCESS: Report generated successfully.');
    } else {
        print('❌ FAILURE: Report file missing.');
    }

  } finally {
    await ws.dispose();
  }
}
