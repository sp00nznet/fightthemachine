# Fight the Machine - Native Builds

This directory contains native Windows implementations that interact with real system processes.

```
native/
├── windows/              # Native Windows port (MinGW/MSYS2)
│   ├── CMakeLists.txt       # Build configuration
│   ├── pr_process.c         # Windows process API (Toolhelp32)
│   ├── build-windows.sh     # MSYS2 build script
│   └── README.md            # Build instructions
│
├── pr_process_win32.c    # Shared process library
├── pr_process_win32.h    # Header file
├── process_blacklist.c   # Protected process list
├── process_blacklist.h   # Header file
├── respawner/            # Process respawner daemon (optional)
└── CMakeLists.txt        # Shared library build
```

## Native Windows Port

The `windows/` subdirectory contains a complete native Windows port of the game:

- Uses **Toolhelp32 API** to enumerate running processes
- Uses **TerminateProcess** to kill real Windows processes
- Includes process blacklist to protect critical system processes
- Safe mode restricts kills to notepad, calc, mspaint only

**No respawner** - killed processes stay dead.

See [windows/README.md](windows/README.md) for build instructions.

## Shared Libraries

The shared `pr_process_win32` library provides:

| Function | Description |
|----------|-------------|
| `pr_init()` / `pr_shutdown()` | Initialize/cleanup |
| `pr_refresh_process_list()` | Scan running processes |
| `pr_kill_process(pid)` | Terminate a process |
| `pr_is_blacklisted(name)` | Check if protected |
| `pr_get_process_tier(name)` | Get DOOM enemy tier |
| `pr_set_safe_mode(enabled)` | Toggle safe mode |

## Process Tiers

| Tier | DOOM Enemy | Examples |
|------|------------|----------|
| 0 | Zombieman | notepad, calc, mspaint |
| 1 | Imp | code, node, python |
| 2 | Demon | chrome, firefox, discord |
| 3 | Cacodemon | dropbox, steam, spotify |
| 4 | Baron of Hell | outlook, excel, word |
| 5 | Cyberdemon | PROTECTED (cannot kill) |
