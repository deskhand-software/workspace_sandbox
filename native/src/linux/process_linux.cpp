#ifndef _WIN32
#include "../common/internal_api.h"
#include <unistd.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <vector>
#include <cstring>
#include <errno.h>
#include <sstream>
#include <string>

/// Helper class to construct the argument list for execvp.
class ArgBuilder {
  std::vector<std::string> storage;

public:
  void add(const std::string& arg) {
    storage.push_back(arg);
  }

  std::vector<char*> getArgs() {
    std::vector<char*> ptrs;
    ptrs.reserve(storage.size() + 1);
    for (auto& s : storage) {
      ptrs.push_back(const_cast<char*>(s.c_str()));
    }
    ptrs.push_back(nullptr);
    return ptrs;
  }

  bool empty() const { return storage.empty(); }
  size_t size() const { return storage.size(); }

  /// Appends the standard bubblewrap (bwrap) security configuration.
  ///
  /// This configuration ensures:
  /// 1. Namespace isolation (PID, IPC, UTS, User).
  /// 2. Empty root filesystem (tmpfs) to prevent host leakage.
  /// 3. Read-only mounting of necessary system binaries (/usr, /lib).
  /// 4. Network namespace isolation if requested.
  void add_bwrap_base(bool allow_network) {
    add("bwrap");
    
    // 1. Namespace Isolation
    add("--unshare-all");
    add("--new-session");
    add("--die-with-parent");

    // 2. Filesystem Construction (Empty Root Strategy)
    // We mount an empty tmpfs at / to ensure no host files are visible by default.
    add("--tmpfs"); add("/");
    
    // Mount /usr (Read-Only) - essential for most binaries
    add("--ro-bind"); add("/usr"); add("/usr");
    
    // Create standard symlinks for merged-usr compatibility (e.g., /bin -> /usr/bin)
    // This allows binaries like /bin/cat or /bin/bash to function.
    add("--symlink"); add("usr/lib"); add("/lib");
    add("--symlink"); add("usr/lib64"); add("/lib64");
    add("--symlink"); add("usr/bin"); add("/bin");
    add("--symlink"); add("usr/sbin"); add("/sbin");
    
    // Mount standard devices
    add("--proc"); add("/proc");
    add("--dev"); add("/dev");
    
    // Clean /tmp (tmpfs)
    add("--tmpfs"); add("/tmp");
    
    // Minimal system configuration (DNS, etc.)
    // We deliberately do NOT mount /home or /root.
    add("--ro-bind-try"); add("/etc/resolv.conf"); add("/etc/resolv.conf");
    add("--ro-bind-try"); add("/etc/hosts"); add("/etc/hosts");
    add("--ro-bind-try"); add("/etc/ssl/certs"); add("/etc/ssl/certs");

    // 3. Privileges and Network
    if (allow_network) {
      add("--share-net");
    } else {
      add("--unshare-net"); 
    }
    
    // Drop all capabilities for depth defense
    add("--cap-drop"); add("ALL");
  }
};

static void set_nonblocking(int fd) {
  int flags = fcntl(fd, F_GETFL, 0);
  if (flags != -1) fcntl(fd, F_SETFL, flags | O_NONBLOCK);
}

/// Simple shell-like command line parser.
/// Handles single quotes, double quotes, and backslash escaping.
static std::vector<std::string> parse_command_line(const char* command_line) {
  std::vector<std::string> parts;
  if (!command_line || !*command_line) return parts;

  std::string cmd(command_line);
  std::string current;
  bool inSingleQuote = false;
  bool inDoubleQuote = false;
  bool escape = false;

  for (size_t i = 0; i < cmd.length(); ++i) {
    char c = cmd[i];
    if (escape) {
      current += c;
      escape = false;
      continue;
    }
    if (c == '\\' && !inSingleQuote) {
      escape = true;
      continue;
    }
    if (c == '\'' && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      continue;
    }
    if (c == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      continue;
    }
    if ((c == ' ' || c == '\t') && !inSingleQuote && !inDoubleQuote) {
      if (!current.empty()) {
        parts.push_back(current);
        current.clear();
      }
      continue;
    }
    current += c;
  }
  if (!current.empty()) parts.push_back(current);
  return parts;
}

// --- Main Entry Point ---

ProcessHandle* StartProcessLinux(
  const char* command_line,
  const char* cwd,
  bool sandbox,
  const char* id,
  bool allow_network
) {
  auto parsed = parse_command_line(command_line);
  if (parsed.empty()) {
    return nullptr;
  }

  ArgBuilder args;

  if (sandbox) {
    args.add_bwrap_base(allow_network);

    if (cwd && *cwd) {
      // Sandbox Strategy: Bind the host CWD to a neutral path (/app).
      // This hides the real path structure from the process.
      args.add("--bind");
      args.add(cwd);    // Host source
      args.add("/app"); // Sandbox destination
      
      args.add("--chdir");
      args.add("/app");
    }

    for (const auto& part : parsed) {
      args.add(part);
    }
  } else {
    for (const auto& part : parsed) {
      args.add(part);
    }
  }

  auto exec_args = args.getArgs();

  // Setup Pipes
  int pipeOut[2], pipeErr[2], pipeExec[2];

  if (pipe(pipeOut) == -1) return nullptr;
  if (pipe(pipeErr) == -1) {
    close(pipeOut[0]); close(pipeOut[1]);
    return nullptr;
  }
  // Pipe used to report execvp errors from child to parent
  if (pipe(pipeExec) == -1) {
    close(pipeOut[0]); close(pipeOut[1]);
    close(pipeErr[0]); close(pipeErr[1]);
    return nullptr;
  }

  // Set Close-on-Exec for the write end of the error reporting pipe
  fcntl(pipeExec[1], F_SETFD, FD_CLOEXEC);

  pid_t pid = fork();
  if (pid == -1) {
    close(pipeOut[0]); close(pipeOut[1]);
    close(pipeErr[0]); close(pipeErr[1]);
    close(pipeExec[0]); close(pipeExec[1]);
    return nullptr;
  }

  if (pid == 0) {
    // --- Child Process ---
    
    // Close read ends
    close(pipeOut[0]);
    close(pipeErr[0]);
    close(pipeExec[0]);

    // Redirect stdout/stderr
    if (dup2(pipeOut[1], STDOUT_FILENO) == -1) _exit(errno);
    if (dup2(pipeErr[1], STDERR_FILENO) == -1) _exit(errno);

    close(pipeOut[1]);
    close(pipeErr[1]);

    // Handle CWD for non-sandboxed processes
    if (cwd && *cwd && !sandbox) {
      if (chdir(cwd) == -1) {
        int err = errno;
        write(pipeExec[1], &err, sizeof(err));
        _exit(1);
      }
    }

    // Execute
    execvp(exec_args[0], exec_args.data());
    
    // If execvp returns, it failed
    int err = errno;
    write(pipeExec[1], &err, sizeof(err));
    _exit(1);
  } else {
    // --- Parent Process ---
    
    close(pipeOut[1]);
    close(pipeErr[1]);
    close(pipeExec[1]);

    // Check if child failed to exec
    int errCode = 0;
    ssize_t readSz = read(pipeExec[0], &errCode, sizeof(errCode));
    close(pipeExec[0]);

    if (readSz > 0) {
      // Child reported an error (e.g., command not found)
      close(pipeOut[0]);
      close(pipeErr[0]);
      waitpid(pid, NULL, 0);
      return nullptr;
    }

    set_nonblocking(pipeOut[0]);
    set_nonblocking(pipeErr[0]);

    ProcessHandle* handle = new ProcessHandle();
    handle->pid = pid;
    handle->fdOut = pipeOut[0];
    handle->fdErr = pipeErr[0];
    handle->isRunning = true;
    handle->exitCode = -1;
    return handle;
  }
}
#endif
