# Fight the Machine - Native Windows Port

This directory contains the native Windows port of psDoom-ng process handling. Instead of running in a VM or container, this version kills **actual Windows processes**.

## WARNING

**This software can terminate running Windows applications and processes. Use with caution!**

- A blacklist protects critical system processes (csrss.exe, lsass.exe, explorer.exe, etc.)
- In "safe mode," only decoy processes (notepad, calc, mspaint) can be killed
- **Run as Administrator** for full functionality
- **Save your work** before playing!

## Components

### pr_process_win32 (Library)

Windows process handling using Toolhelp32 API:

- `pr_init()` / `pr_shutdown()` - Initialize/cleanup
- `pr_refresh_process_list()` - Scan running processes
- `pr_kill_process(pid)` - Terminate a process
- `pr_renice_process(pid)` - Lower process priority
- `pr_is_blacklisted(name)` - Check if process is protected
- `pr_get_process_tier(name)` - Get DOOM enemy tier for process
- `pr_set_safe_mode(enabled)` - Toggle safe mode

### process-respawner.exe

Native Windows daemon that respawns killed processes:

- Monitors all running processes
- When a process is killed, schedules respawn with tier-based delay
- DOOM enemy tiers determine respawn time:
  - **Zombieman** (5-10s): notepad, calc, mspaint
  - **Imp** (8-15s): code, node, python
  - **Demon** (12-20s): chrome, firefox, discord
  - **Cacodemon** (15-25s): dropbox, steam
  - **Baron** (20-30s): outlook, excel, word

### test-process-lib.exe

Test application for the process library:

```bash
# List all processes
test-process-lib --list

# Enable safe mode
test-process-lib --safe --list

# Spawn decoy processes for testing
test-process-lib --spawn

# Kill a process (use safe mode first!)
test-process-lib --safe --kill 12345
```

## Building

### Option 1: MSYS2 (Recommended)

1. Install [MSYS2](https://www.msys2.org/)
2. Open **MSYS2 MINGW64** terminal
3. Install dependencies:
   ```bash
   pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake make
   ```
4. Build:
   ```bash
   cd native
   ./build-msys2.sh
   ```

### Option 2: Visual Studio

1. Open Developer Command Prompt
2. Build:
   ```cmd
   cd native
   mkdir build && cd build
   cmake -G "Visual Studio 17 2022" -A x64 ..
   cmake --build . --config Release
   ```

## Integrating with psDoom-ng

To make psDoom-ng use Windows processes instead of Linux /proc:

1. Replace `src/doom/pr_process.c` with the Windows implementation
2. Modify process iteration to use `pr_get_process_list()`
3. Modify process killing to use `pr_kill_process()`
4. Build psDoom-ng with SDL 1.2 for Windows (via MSYS2)

## Process Tiers (DOOM Enemy Mapping)

| Tier | DOOM Enemy | Processes | Respawn Delay |
|------|------------|-----------|---------------|
| 0 | Zombieman | notepad, calc, mspaint | 5-10 seconds |
| 1 | Imp | code, node, python, cmd | 8-15 seconds |
| 2 | Demon | chrome, firefox, discord | 12-20 seconds |
| 3 | Cacodemon | dropbox, steam, onedrive | 15-25 seconds |
| 4 | Baron of Hell | outlook, excel, word | 20-30 seconds |
| 5 | Cyberdemon | PROTECTED - cannot kill | N/A |

## Protected Processes (Blacklist)

The following processes are **protected** and cannot be killed:

- **Windows Core**: system, csrss.exe, lsass.exe, services.exe, svchost.exe
- **Windows Shell**: explorer.exe, dwm.exe, winlogon.exe
- **Security**: msmpeng.exe (Windows Defender)
- **This Game**: psdoom-ng.exe, fightthemachine.exe, process-respawner.exe

Attempting to kill these will fail silently to prevent system crashes.

## Safe Mode

Safe mode restricts the game to only kill specific "decoy" processes:

- notepad.exe
- calc.exe
- mspaint.exe

Enable safe mode for testing without risking real applications:

```c
pr_set_safe_mode(1);  // Enable safe mode
pr_spawn_decoy_process("notepad");  // Spawn targets
```

## License

Part of the Fight the Machine project - see LICENSE in project root.
