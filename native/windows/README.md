# Fight the Machine - Native Windows Build

**Kill Windows processes by killing DOOM monsters!**

This is a native Windows build that runs directly on Windows and kills **real Windows processes** when you kill monsters in the game.

## Credits & Acknowledgments

This project stands on the shoulders of giants. **Fight the Machine is built on open source software and we don't own it - we're just building on the amazing work of others:**

- **[DOOM](https://github.com/id-Software/DOOM)** - id Software (1993) - The legendary game that started it all
- **[Chocolate Doom](https://www.chocolate-doom.org/)** - Simon Howard - A faithful, cross-platform DOOM source port
- **[psDoom](http://psdoom.sourceforge.net/)** - Dennis Chao (1999) - The original "process killing DOOM" concept
- **[psDoom-ng](https://github.com/orsonteodoro/psdoom-ng)** - Orson Teodoro - Modern psDoom port based on Chocolate Doom
- **[psDoom-ng (keymon fork)](https://github.com/keymon/psdoom-ng)** - keymon - Additional psDoom-ng development

All of this is **free and open source software** under the GPL v2 license. We encourage you to explore these projects, contribute to them, and build your own cool stuff!

---

## What This Does

When you kill a monster in DOOM, it kills the corresponding real Windows process using the Windows `TerminateProcess` API. This is not a simulation - it's the real thing.

### Process → Monster Mapping

| Windows Process | DOOM Monster |
|----------------|--------------|
| `notepad.exe`, `calc.exe`, `mspaint.exe` | Zombieman (weak) |
| `code.exe`, `node.exe`, `python.exe`, `powershell.exe` | Imp (medium) |
| `chrome.exe`, `firefox.exe`, `discord.exe`, `spotify.exe` | Demon (tough) |
| `dropbox.exe`, `steam.exe`, `onedrive.exe` | Cacodemon (tougher) |
| `outlook.exe`, `excel.exe`, `winword.exe` | Baron of Hell (boss) |
| System processes (`svchost.exe`, `explorer.exe`, etc.) | Cyberdemon (PROTECTED) |

## Quick Start

1. Extract the ZIP file
2. Double-click `run.bat`
3. Kill monsters = Kill processes!

## Configuration

Edit `fightthemachine.cfg` to customize:

```ini
# Scale factor (2-6): 2=640x400, 3=960x600, 4=1280x800, etc.
SCALE=2

# Windowed mode (1=yes, 0=fullscreen)
WINDOWED=1

# Safe mode (1=only safe processes, 0=all processes)
SAFE_MODE=1
```

## Building from Source

### Prerequisites

1. Install [MSYS2](https://www.msys2.org/)
2. Open **MSYS2 MINGW64** terminal
3. Install dependencies:

```bash
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake \
          mingw-w64-x86_64-SDL mingw-w64-x86_64-SDL_mixer \
          mingw-w64-x86_64-SDL_net mingw-w64-x86_64-libpng \
          git make
```

### Build

```bash
git clone https://github.com/sp00nznet/fightthemachine.git
cd fightthemachine/native/windows
./build-windows.sh
```

## Safe Mode

By default, **safe mode is enabled** - only these harmless processes can be killed:
- `notepad.exe`
- `calc.exe`
- `mspaint.exe`

## Protected Processes

These system processes are **always protected** and cannot be killed:

- **Windows Core**: `system`, `smss.exe`, `csrss.exe`, `wininit.exe`, `services.exe`, `lsass.exe`, `svchost.exe`
- **Windows Shell**: `explorer.exe`, `dwm.exe`
- **Security**: `msmpeng.exe`, `securityhealthservice.exe`

## Cheat Codes

| Cheat | Effect |
|-------|--------|
| `sudo` | God mode + all weapons |
| `iddqd` | God mode |
| `idkfa` | All weapons and ammo |
| `idclip` | Walk through walls |

## License

This project is licensed under **GPL v2** - the same license as DOOM, Chocolate Doom, and psDoom-ng.

**This is free software.** You are free to use, modify, and distribute it under the terms of the GPL v2.

## Disclaimer

**USE AT YOUR OWN RISK.** This software can terminate Windows processes. While safety measures are in place, the authors are not responsible for any damage caused.

---

*Fight the Machine is a community project built on open source foundations. We don't own DOOM, psDoom, or any of the underlying technology - we just love building cool stuff with it.*
