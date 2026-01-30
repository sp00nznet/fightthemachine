# Fight the Machine - Native Windows Port

This is a **true native Windows port** of psDoom-ng that runs directly on Windows and kills **real Windows processes** - not processes inside a container.

## What This Does

When you kill a monster in DOOM, it kills the corresponding real Windows process using the Windows `TerminateProcess` API. This is not a simulation or container - it's the real thing.

### Process → Monster Mapping

| Windows Process | DOOM Monster |
|----------------|--------------|
| `notepad.exe`, `calc.exe`, `mspaint.exe` | Zombieman (weak) |
| `code.exe`, `node.exe`, `python.exe`, `powershell.exe` | Imp (medium) |
| `chrome.exe`, `firefox.exe`, `discord.exe`, `spotify.exe` | Demon (tough) |
| `dropbox.exe`, `steam.exe`, `onedrive.exe` | Cacodemon (tougher) |
| `outlook.exe`, `excel.exe`, `winword.exe` | Baron of Hell (boss) |
| System processes (`svchost.exe`, `explorer.exe`, etc.) | Cyberdemon (PROTECTED - cannot be killed) |

## Building on Windows

### Prerequisites

1. Install [MSYS2](https://www.msys2.org/)
2. Open **MSYS2 MINGW64** terminal (important: use MINGW64, not MSYS)
3. Install dependencies:

```bash
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake \
          mingw-w64-x86_64-SDL mingw-w64-x86_64-SDL_mixer \
          mingw-w64-x86_64-SDL_net mingw-w64-x86_64-libpng \
          git make
```

### Build Steps

```bash
# Clone the repository
git clone https://github.com/sp00nznet/fightthemachine.git
cd fightthemachine/native/psdoom-win32

# Build (safe mode enabled by default)
./build-windows.sh

# Or build with unsafe mode (kills all processes!)
./build-windows.sh --unsafe
```

### Manual Build (Alternative)

```bash
cd fightthemachine/native/psdoom-win32
mkdir build && cd build

cmake -G "MSYS Makefiles" \
      -DCMAKE_BUILD_TYPE=Release \
      -DENABLE_SAFE_MODE=ON \
      ..

cmake --build . --parallel
```

## Running

You need the DOOM shareware WAD file (`DOOM1.WAD`). You can get it from:
- The `doom-wad-shareware` package on Linux
- Download from [Doomworld](https://www.doomworld.com/classicdoom/info/shareware.php)

```bash
./psdoom-ng.exe -iwad DOOM1.WAD -file psdoom1.wad -window
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-window` | Run in windowed mode |
| `-fullscreen` | Run in fullscreen mode |
| `-nopsmon` | Disable process monitoring (no process monsters) |
| `-nopsact` | Disable process killing (monsters spawn but killing them doesn't kill processes) |
| `-psallusers` | Show all users' processes (by default, only shows your processes) |

## Safe Mode

By default, the game runs in **safe mode** which only allows killing these processes:
- `notepad.exe`
- `calc.exe`
- `mspaint.exe`

These processes are harmless and can be easily restarted. To disable safe mode and allow killing all non-protected processes, build with `--unsafe` or set `ENABLE_SAFE_MODE=OFF` in CMake.

## Protected Processes (Cannot Be Killed)

These critical system processes are **always protected** and cannot be killed, even with safe mode disabled:

- **Windows Core**: `system`, `smss.exe`, `csrss.exe`, `wininit.exe`, `services.exe`, `lsass.exe`, `svchost.exe`, `dwm.exe`, `winlogon.exe`
- **Windows Shell**: `explorer.exe`, `searchui.exe`, `shellexperiencehost.exe`
- **Security**: `msmpeng.exe`, `securityhealthservice.exe`
- **This Game**: `psdoom-ng.exe`, `psdoom.exe`

## How It Works

### Process Enumeration

The game uses the Windows Toolhelp32 API (`CreateToolhelp32Snapshot`, `Process32First`, `Process32Next`) to enumerate all running processes.

```c
HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
PROCESSENTRY32 pe32;
pe32.dwSize = sizeof(PROCESSENTRY32);
Process32First(hSnap, &pe32);
do {
    // Add process to monster list
} while (Process32Next(hSnap, &pe32));
```

### Process Killing

When you kill a monster, it calls `TerminateProcess`:

```c
HANDLE hProc = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
TerminateProcess(hProc, 1);
CloseHandle(hProc);
```

### Priority Adjustment

When you damage a monster (shoot but don't kill), it lowers the process priority:

```c
HANDLE hProc = OpenProcess(PROCESS_SET_INFORMATION, FALSE, pid);
SetPriorityClass(hProc, BELOW_NORMAL_PRIORITY_CLASS);
```

## Cheat Codes

| Cheat | Effect |
|-------|--------|
| `sudo` | God mode + all weapons (IDDQD + IDKFA combined) |
| `iddqd` | God mode |
| `idkfa` | All weapons, keys, and ammo |
| `idclip` | No clipping (walk through walls) |

## Differences from Linux Version

| Feature | Linux | Windows Native |
|---------|-------|----------------|
| Process enumeration | `popen("ps ...")` | `CreateToolhelp32Snapshot` |
| Process killing | `system("kill -9")` | `TerminateProcess` |
| Priority adjustment | `system("renice")` | `SetPriorityClass` |
| Daemon detection | TTY = '?' | Running as SYSTEM user |

## Security Considerations

**This software can terminate Windows processes.** While it has safety measures:

1. Protected process blacklist (system processes cannot be killed)
2. Safe mode option (only kills harmless processes)
3. User permission checks (can only kill processes you own)

**Use at your own risk.** The authors are not responsible for any damage caused by terminating processes.

## License

- psDoom-ng: GPL v2 (same as DOOM source)
- Windows port modifications: GPL v2

## Credits

- Original DOOM: id Software
- Chocolate Doom: Simon Howard
- psDoom: Dennis Chao
- psDoom-ng: David Koppenhofer, Jesse Spielman, Hector Rivas Gandara
- Windows port: Fight the Machine Project
