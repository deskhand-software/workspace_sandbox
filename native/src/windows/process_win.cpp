#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "../include/workspace_core.h"
#include "common/internal_api.h"

#ifdef _WIN32
  #include <windows.h>
#else
  #include <unistd.h>
  #include <sys/wait.h>
  #include <signal.h>
  #include <errno.h>
#endif

extern "C" {

WORKSPACE_EXPORT ProcessHandle* workspace_start(WorkspaceOptionsC* options) {
  if (!options || !options->command_line) {
    return nullptr;
  }

#ifdef _WIN32
  // NOTA: En Windows, por ahora pasamos false/ignorado o implementamos lógica.
  // Si quieres implementar Windows Isolation real, necesitamos actualizar 
  // StartProcessWindows para aceptar allow_network.
  // Por ahora, lo pasamos para mantener la firma consistente si decides actualizar process_win.cpp
  return StartProcessWindows(
    options->command_line,
    options->cwd,
    options->sandbox,
    options->id
    //, options->allow_network  <-- DESCOMENTAR CUANDO ACTUALICEMOS WINDOWS
  );
#else
  return StartProcessLinux(
    options->command_line,
    options->cwd,
    options->sandbox,
    options->id,
    options->allow_network // <--- PASANDO LA OPCIÓN A LINUX
  );
#endif
}

// ... Resto del archivo (read_stdout, etc.) IGUAL ...

} // extern "C"
