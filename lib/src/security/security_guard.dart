import '../models/workspace_options.dart';

class SecurityGuard {
  /// Binaries known to require network access.
  static const _networkBinaries = {
    'curl',
    'wget',
    'git',
    'ssh',
    'npm',
    'pip',
    'ping',
    'telnet',
    'nc',
    'netcat',
    'ftp',
    'sftp',
    'scp',
    'rsync'
  };

  /// Validates if a command violates security policies before execution.
  ///
  /// Throws [Exception] if a violation is detected.
  static void inspectCommand(String commandLine, WorkspaceOptions options) {
    final parts = commandLine.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return;

    final cmd = parts.first.toLowerCase();

    // 1. Network Block (Heuristic Layer)
    if (!options.allowNetwork) {
      if (_networkBinaries.contains(cmd)) {
        throw Exception(
            'SECURITY VIOLATION: Command "$cmd" requires network access, '
            'but allowNetwork is false.');
      }

      // PowerShell network check
      if (cmd == 'powershell' || cmd == 'pwsh') {
        if (commandLine.contains('Net.Sockets') ||
            commandLine.contains('WebRequest') ||
            commandLine.contains('RestMethod')) {
          throw Exception(
              'SECURITY VIOLATION: PowerShell network call detected while allowNetwork is false.');
        }
      }

      // Python socket check
      if ((cmd == 'python' || cmd == 'python3') &&
          commandLine.contains('socket')) {
        throw Exception(
            'SECURITY VIOLATION: Python socket usage detected while allowNetwork is false.');
      }
    }
  }
}
