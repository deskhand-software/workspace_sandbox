#ifndef WORKSPACE_CORE_H
#define WORKSPACE_CORE_H

#include <stdint.h>
// #include <stdbool.h>

#ifdef _WIN32
  #define WORKSPACE_EXPORT __declspec(dllexport)
#else
  #define WORKSPACE_EXPORT __attribute__((visibility("default")))
#endif

extern "C" {

  /// Options passed from Dart to the native workspace core.
  ///
  /// All strings are UTF-8 encoded and owned by the caller.
  typedef struct {
    /// Full command line to execute, as a single UTF-8 string.
    const char* command_line;

    /// Optional working directory for the process (UTF-8 path).
    /// May be null to use the current process working directory.
    const char* cwd;

    /// Whether the process should run inside a sandbox.
    int32_t sandbox;

    /// Logical workspace identifier.
    const char* id;

    /// If false, network access is blocked (isolation).
    /// Ignored if sandbox is false.
    int32_t allow_network; 
  } WorkspaceOptionsC;

  /// Opaque handle to a native process managed by the workspace core.
  typedef struct ProcessHandle ProcessHandle;

  /// Starts a new process using the given options.
  WORKSPACE_EXPORT ProcessHandle* workspace_start(WorkspaceOptionsC* options);

  WORKSPACE_EXPORT int workspace_read_stdout(
    ProcessHandle* handle,
    char* buffer,
    int size
  );

  WORKSPACE_EXPORT int workspace_read_stderr(
    ProcessHandle* handle,
    char* buffer,
    int size
  );

  WORKSPACE_EXPORT int workspace_is_running(
    ProcessHandle* handle,
    int* exit_code
  );

  WORKSPACE_EXPORT void workspace_kill(ProcessHandle* handle);

  WORKSPACE_EXPORT void workspace_free_handle(ProcessHandle* handle);
}

#endif // WORKSPACE_CORE_H
