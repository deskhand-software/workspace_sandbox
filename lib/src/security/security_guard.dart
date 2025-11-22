import '../models/workspace_options.dart';

/// Static analyzer for preventing obvious security violations in command strings.
///
/// This is a heuristic layer (Defense-in-Depth) and does not replace the
/// robust OS-level sandboxing provided by the native core.
class SecurityGuard {
  /// Binaries known to primarily require network access.
  static const _networkBinaries = {
    'curl',
    'wget',
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

    // Normalize command to lowercase to catch 'CuRl' or 'WGET'
    final cmd = parts.first.toLowerCase();
    final fullCmdLower = commandLine.toLowerCase();

    // 1. Network Block (Heuristic Layer)
    if (!options.allowNetwork) {
      if (_networkBinaries.contains(cmd)) {
        throw Exception(
            'SECURITY VIOLATION: Command "$cmd" requires network access, '
            'but allowNetwork is false.');
      }

      // PowerShell network check
      if (cmd == 'powershell' ||
          cmd == 'pwsh' ||
          cmd.endsWith('powershell.exe')) {
        if (fullCmdLower.contains('net.sockets') ||
            fullCmdLower.contains('webrequest') ||
            fullCmdLower.contains('restmethod')) {
          throw Exception(
              'SECURITY VIOLATION: PowerShell network call detected while allowNetwork is false.');
        }
      }

      // Python socket/http check
      if (cmd == 'python' || cmd == 'python3' || cmd.endsWith('python.exe')) {
        // More robust check for common network libraries
        if (fullCmdLower.contains('import socket') ||
            fullCmdLower.contains('from socket') ||
            fullCmdLower.contains('urllib') ||
            fullCmdLower.contains('http.client') ||
            fullCmdLower.contains('requests')) {
          throw Exception(
              'SECURITY VIOLATION: Python network library usage detected while allowNetwork is false.');
        }
      }

      // Node.js network check
      if (cmd == 'node' || cmd == 'node.exe') {
        if (fullCmdLower.contains("require('net')") ||
            fullCmdLower.contains('require("net")') ||
            fullCmdLower.contains("require('http')") ||
            fullCmdLower.contains('require("http")') ||
            fullCmdLower.contains('child_process')) {
          throw Exception(
              'SECURITY VIOLATION: Node.js network/process library usage detected while allowNetwork is false.');
        }
      }
    }
  }
}
