# Fight the Machine

```
    ███████╗██╗ ██████╗ ██╗  ██╗████████╗    ████████╗██╗  ██╗███████╗
    ██╔════╝██║██╔════╝ ██║  ██║╚══██╔══╝    ╚══██╔══╝██║  ██║██╔════╝
    █████╗  ██║██║  ███╗███████║   ██║          ██║   ███████║█████╗
    ██╔══╝  ██║██║   ██║██╔══██║   ██║          ██║   ██╔══██║██╔══╝
    ██║     ██║╚██████╔╝██║  ██║   ██║          ██║   ██║  ██║███████╗
    ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝          ╚═╝   ╚═╝  ╚═╝╚══════╝
              ███╗   ███╗ █████╗  ██████╗██╗  ██╗██╗███╗   ██╗███████╗
              ████╗ ████║██╔══██╗██╔════╝██║  ██║██║████╗  ██║██╔════╝
              ██╔████╔██║███████║██║     ███████║██║██╔██╗ ██║█████╗
              ██║╚██╔╝██║██╔══██║██║     ██╔══██║██║██║╚██╗██║██╔══╝
              ██║ ╚═╝ ██║██║  ██║╚██████╗██║  ██║██║██║ ╚████║███████╗
              ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝
```

**Kill processes by killing DOOM monsters.**

---

## What Is This?

Fight the Machine turns your running processes into DOOM monsters. Kill the monster, kill the process. It's that simple.

| Build | What Gets Killed | Features | Safety |
|-------|------------------|----------|--------|
| [Native Windows](#native-windows) | Real Windows processes | Direct, fast, no VM | Dangerous |
| [Win32 QEMU](#win32-qemu-client) | VM processes only | Respawner, File Spawner | Safe |

---

## Project Structure

```
fightthemachine/
│
├── native/                 # Native Windows builds
│   └── windows/               # Native Windows port (DANGEROUS)
│       ├── CMakeLists.txt         # CMake build config
│       ├── pr_process.c           # Windows process API
│       ├── build-windows.sh       # MSYS2 build script
│       ├── fightthemachine.cfg    # User config file
│       ├── run.bat                # Launcher
│       └── README.md
│
├── win32/                  # Win32 QEMU client (SAFE)
│   ├── main.cpp               # WebView2 GUI wrapper
│   ├── CMakeLists.txt         # Build config
│   └── README.md
│
├── qemu/                   # QEMU VM build scripts
│   ├── build-vm-image.sh      # Creates bootable Linux VM
│   ├── package-windows.ps1    # Windows packaging script
│   └── vm-init.sh             # VM initialization
│
├── wad/                    # DOOM level data
│   ├── psdoom1.wad            # Process spawn levels
│   ├── psdoom2.wad
│   └── xdoom.wad
│
├── patches/                # Source patches
│   └── add-sudo-cheat.sh      # Adds 'sudo' cheat code
│
└── archive/                # Legacy/historical files
```

---

## Native Windows

**DANGEROUS** - Kills real Windows processes using `TerminateProcess` API.

```
┌──────────────────────────────────────────────────────────────────┐
│                      WINDOWS DESKTOP                              │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                   fightthemachine.exe                       │  │
│  │                      (SDL 1.2)                              │  │
│  └───────────────────────────┬────────────────────────────────┘  │
│                              │                                    │
│              ┌───────────────┼───────────────┐                    │
│              │               │               │                    │
│              ▼               ▼               ▼                    │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐         │
│  │ Toolhelp32    │  │ TerminateProc │  │ Process       │         │
│  │ Snapshot      │  │ API           │  │ Blacklist     │         │
│  │               │  │               │  │               │         │
│  │ Enumerates    │  │ Kills real    │  │ Protects      │         │
│  │ all running   │  │ Windows       │  │ critical      │         │
│  │ processes     │  │ processes     │  │ system procs  │         │
│  └───────────────┘  └───────────────┘  └───────────────┘         │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                    RUNNING PROCESSES                        │  │
│  │                                                             │  │
│  │  notepad.exe    chrome.exe    discord.exe    spotify.exe   │  │
│  │   (zombie)       (demon)       (demon)      (cacodemon)    │  │
│  │                                                             │  │
│  │  explorer.exe   svchost.exe   csrss.exe     lsass.exe     │  │
│  │  (PROTECTED)    (PROTECTED)   (PROTECTED)   (PROTECTED)    │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  NO RESPAWNER - killed processes stay dead!                      │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

### Quick Start

1. Download the release ZIP
2. Extract and run `run.bat`
3. Kill monsters = Kill real processes

See [native/windows/README.md](native/windows/README.md) for build instructions.

---

## Win32 QEMU Client

**Safe** - Runs psDoom in a Linux virtual machine. Processes die inside the VM only.

```
┌──────────────────────────────────────────────────────────────────┐
│                      WINDOWS HOST                                 │
│                                                                   │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                  fightthemachine.exe                        │  │
│  │                  (Win32 GUI + WebView2)                     │  │
│  └───────────────────────────┬────────────────────────────────┘  │
│                              │                                    │
│                              ▼                                    │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                      QEMU VM                                │  │
│  │                                                             │  │
│  │  ┌──────────────────────────────────────────────────────┐  │  │
│  │  │                  Linux Guest                          │  │  │
│  │  │                                                       │  │  │
│  │  │   ┌─────────────┐    ┌─────────────────────────────┐ │  │  │
│  │  │   │ psDoom-ng   │───▶│    Process Respawner        │ │  │  │
│  │  │   │             │    │                             │ │  │  │
│  │  │   │  Kill       │    │  ┌─────┐ ┌─────┐ ┌─────┐   │ │  │  │
│  │  │   │  Monster ───────▶│  │ cat │ │ vim │ │ top │   │ │  │  │
│  │  │   │             │    │  └─────┘ └─────┘ └─────┘   │ │  │  │
│  │  │   └─────────────┘    │                             │ │  │  │
│  │  │                      │  Process dies, respawns     │ │  │  │
│  │  │                      └─────────────────────────────┘ │  │  │
│  │  │                                                       │  │  │
│  │  │   File Spawner creates new processes dynamically     │  │  │
│  │  │                                                       │  │  │
│  │  └──────────────────────────────────────────────────────┘  │  │
│  │                                                             │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  Your Windows processes are completely safe!                     │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

Features:
- **Process Respawner** - killed processes respawn after a delay based on enemy tier
- **File Spawner** - creates processes dynamically for the game
- Native Windows GUI wrapper with WebView2

See [win32/README.md](win32/README.md) for build instructions and [qemu/](qemu/) for VM build scripts.

---

## Controls

| Key | Action |
|-----|--------|
| `↑` `↓` `←` `→` | Move |
| `Ctrl` | Fire |
| `Space` | Use / Open doors |
| `1-7` | Select weapon |
| `Tab` | Automap |
| `Esc` | Menu |

## Cheat Codes

| Cheat | Effect |
|-------|--------|
| `sudo` | God mode + all weapons (Fight the Machine exclusive) |
| `iddqd` | God mode |
| `idkfa` | All weapons and ammo |
| `idclip` | Walk through walls |

---

## Process → Monster Mapping

| Monster | Health | Process Type | Examples |
|---------|--------|--------------|----------|
| Zombieman | Low | Trivial | `notepad`, `calc`, `mspaint` |
| Imp | Medium | Dev tools | `code`, `node`, `python` |
| Demon | High | Apps | `chrome`, `firefox`, `discord` |
| Cacodemon | Higher | Services | `dropbox`, `steam`, `spotify` |
| Baron of Hell | Boss | Office | `outlook`, `excel`, `winword` |
| Cyberdemon | Invincible | PROTECTED | `explorer`, `svchost`, `csrss`, `claude` |

---

## Credits & Acknowledgments

**This project stands on the shoulders of giants.**

Fight the Machine is built entirely on open source software. We don't own any of the underlying technology - we're just building on the amazing work of others:

| Project | Author | What It Is |
|---------|--------|------------|
| [DOOM](https://github.com/id-Software/DOOM) | id Software (1993) | The legendary game that started it all |
| [Chocolate Doom](https://www.chocolate-doom.org/) | Simon Howard | Faithful cross-platform DOOM source port |
| [psDoom](http://psdoom.sourceforge.net/) | Dennis Chao (1999) | The original "kill processes in DOOM" concept |
| [psDoom-ng](https://github.com/orsonteodoro/psdoom-ng) | Orson Teodoro | Modern psDoom port based on Chocolate Doom |
| [psDoom-ng fork](https://github.com/keymon/psdoom-ng) | keymon | Additional psDoom-ng development |

**All of this is free and open source software under the GPL v2 license.**

We encourage you to explore these projects, contribute to them, and build your own cool stuff!

---

## License

This project is licensed under **GPL v2** - the same license as DOOM, Chocolate Doom, and psDoom-ng.

**This is free software.** You are free to use, modify, and distribute it under the terms of the GPL v2.

---

## Repositories

- **GitHub:** https://github.com/sp00nznet/fightthemachine
- **GitLab:** https://buildforever.cloud/sp00nz/fightthemachine

---

<p align="center"><i>RIP AND TEAR, UNTIL IT IS DONE.</i></p>
