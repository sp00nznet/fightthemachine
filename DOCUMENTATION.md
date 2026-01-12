# Fight the Machine - Documentation

## Table of Contents

- [Architecture](#architecture)
- [Engine Migration](#engine-migration)
- [Cheat Codes](#cheat-codes)
- [Configuration](#configuration)
- [Process Respawner](#process-respawner)
- [Building](#building)
- [Troubleshooting](#troubleshooting)
- [File Structure](#file-structure)
- [Development History](#development-history)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Your Browser                            │
│                     http://localhost:6080                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │ HTML5 WebSocket
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Docker Container                           │
│                                                                 │
│   ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌───────────┐   │
│   │  noVNC  │───▶│ x11vnc  │───▶│  Xvfb   │◀───│ psDoom-ng │   │
│   │ (HTML5) │    │  (VNC)  │    │  (X11)  │    │  (game)   │   │
│   └─────────┘    └─────────┘    └─────────┘    └─────┬─────┘   │
│                                                      │         │
│   ┌────────────────┐                                 │         │
│   │    Process     │◀────────────────────────────────┘         │
│   │   Respawner    │   kills process → monster dies            │
│   └────────────────┘   respawns process → monster returns      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Components

| Component | Purpose |
|-----------|---------|
| **Xvfb** | Virtual X11 framebuffer - provides a display without physical monitor |
| **psDoom-ng** | The game engine - maps processes to monsters |
| **x11vnc** | Captures the virtual display as a VNC stream |
| **noVNC** | Converts VNC to HTML5 WebSocket for browser access |
| **Process Respawner** | Restarts killed processes to keep the game going |
| **Supervisor** | Manages all services, restarts crashed components |

---

## Engine Migration

### From XDoom to Chocolate Doom

Fight the Machine originally used the **XDoom-based psDoom** from 2000. This was replaced with **psDoom-ng**, a modern port based on **Chocolate Doom**.

#### Why We Switched

| Issue | XDoom (Original) | Chocolate Doom (psDoom-ng) |
|-------|------------------|---------------------------|
| **Architecture** | 32-bit only | Native 64-bit support |
| **Dependencies** | Ancient libraries (libc5, Xaw3d) | Modern SDL 1.2 |
| **Stability** | Frequent segfaults, memory issues | Battle-tested stability |
| **Build System** | Manual Makefiles, broken paths | Autotools, builds cleanly |
| **Maintenance** | Abandoned since 2000 | Active development |
| **DOOM Accuracy** | Modified/broken behaviors | Vanilla-accurate |

#### Migration Challenges Solved

1. **Build System**: psDoom-ng uses autotools but had a broken desktop file target. Fixed by allowing partial build failure after binary compilation.

2. **WAD Compatibility**: The shareware DOOM1.WAD doesn't support the `-file` flag for addon WADs. Required custom handling in the startup script.

3. **Display Scaling**: Original attempts to use psDoom's scaling flags caused graphical glitches. Solved by using noVNC's built-in scaling instead.

4. **Process Monitoring**: The original `-psmon` flag caused crashes on some systems. Various flags (`-nopsmon`, `-nopslev`, `-nomonsters`) were tested to isolate issues.

---

## Cheat Codes

Type these codes during gameplay (no need to press Enter):

### Standard DOOM Cheats

| Code | Effect |
|------|--------|
| `iddqd` | **God Mode** - Invincibility |
| `idkfa` | **Full Arsenal** - All weapons, max ammo, all keys, 200% armor |
| `idfa` | **Ammo & Weapons** - All weapons, max ammo (no keys) |
| `idclip` | **No-Clip** - Walk through walls |
| `iddt` | **Map Reveal** - Shows full automap (type twice for enemy positions) |
| `idbehold` | **Power-up Menu** - Press S/I/V/A/R/L after for power-ups |
| `idchoppers` | **Chainsaw** - Gives you the chainsaw |
| `idspispopd` | **No-Clip** (alternate) - Same as idclip |
| `idclev##` | **Level Warp** - Go to Episode # Map # (e.g., `idclev12` for E1M2) |
| `idmus##` | **Change Music** - Play music from specified level |

### Fight the Machine Exclusive

| Code | Effect |
|------|--------|
| **`sudo`** | **Superuser Mode** - Combines IDDQD + IDKFA |

The `sudo` cheat is a nod to Unix/Linux system administration. Just like `sudo` grants root privileges, typing `sudo` in Fight the Machine grants you god mode AND a full arsenal simultaneously.

When activated, you'll see: `SUDO: God mode + full arsenal activated!`

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RESOLUTION` | `1024x768` | Virtual display resolution |
| `VNC_PORT` | `5900` | VNC server port |
| `NOVNC_PORT` | `6080` | noVNC web interface port |
| `DISPLAY` | `:0` | X11 display number |

### Custom Resolution

In `docker-compose.yml`:
```yaml
services:
  fightthemachine:
    environment:
      - RESOLUTION=1920x1080
```

Or via command line:
```bash
docker run -e RESOLUTION=1920x1080 -p 6080:6080 fightthemachine
```

### Resource Limits

Default limits in `docker-compose.yml`:
- **CPU**: 2 cores
- **Memory**: 1GB

To adjust:
```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 2G
```

---

## Process Respawner

The respawner ensures killed processes come back, making the game endless.

### Respawn Delays by Enemy Tier

| Enemy Type | Process Examples | Respawn Delay |
|------------|------------------|---------------|
| Zombieman | `cat`, `sleep`, `echo` | 5-10 seconds |
| Imp | `vim`, `python`, `grep` | 8-15 seconds |
| Demon | Window managers | 12-20 seconds |
| Cacodemon | `cron`, networking | 15-25 seconds |
| Baron of Hell | `init`, X server | 20-30 seconds |

### Viewing Respawner Logs

```bash
docker exec fightthemachine tail -f /var/log/process-respawner.log
```

---

## Building

### Standard Build

```bash
./run.sh build
```

### Manual Docker Build

```bash
docker build -t fightthemachine .
```

### Run Without Compose

```bash
docker run -d \
  --name fightthemachine \
  -p 6080:6080 \
  -p 5900:5900 \
  --cap-add SYS_PTRACE \
  fightthemachine
```

### Build Process Overview

The Dockerfile:
1. Installs build dependencies (SDL 1.2, autotools, X11 libs)
2. Clones psDoom-ng from GitHub
3. Applies the `sudo` cheat code patch
4. Builds the game engine
5. Sets up noVNC, x11vnc, Xvfb
6. Configures Supervisor to manage all services

---

## Troubleshooting

### Cannot Connect to http://localhost:6080

1. Check if container is running:
   ```bash
   ./run.sh status
   ```
2. View startup logs:
   ```bash
   ./run.sh logs
   ```
3. Wait ~30 seconds after starting (services need time to initialize)
4. Try a different browser or incognito mode

### Black Screen in Browser

1. Check if Xvfb is running:
   ```bash
   docker exec fightthemachine pgrep Xvfb
   ```
2. Check game logs:
   ```bash
   docker exec fightthemachine cat /var/log/supervisor/psdoom.log
   ```
3. Rebuild the image:
   ```bash
   ./run.sh build && ./run.sh start
   ```

### Game Crashes

1. Check error log:
   ```bash
   docker exec fightthemachine cat /var/log/supervisor/psdoom.err
   ```
2. Verify WAD files exist:
   ```bash
   docker exec fightthemachine ls -la /usr/share/games/doom/
   ```
3. Test manual launch:
   ```bash
   docker exec -it fightthemachine /usr/local/bin/psdoom-ng -iwad /usr/share/games/doom/doom1.wad
   ```

### VNC Client Won't Connect

VNC is passwordless by default. To set a password:
```bash
docker exec fightthemachine x11vnc -storepasswd yourpassword /tmp/vncpass
```

### Graphics Look Garbled

This was a known issue with x11vnc shared memory. The current build uses `-noshm` flag to prevent this. If it occurs:

1. Restart the container:
   ```bash
   ./run.sh restart
   ```
2. Try the scaling option in noVNC (gear icon → Scaling Mode → Local Scaling)

---

## File Structure

```
fightthemachine/
├── Dockerfile              # Container build instructions
├── docker-compose.yml      # Compose configuration
├── run.sh                  # Linux/Mac launcher script
├── run.bat                 # Windows launcher script
├── README.md               # Quick start guide
├── DOCUMENTATION.md        # This file
├── docker/
│   ├── supervisord.conf    # Service manager config
│   ├── start-psdoom.sh     # Game launcher script
│   ├── start-vnc.sh        # VNC/noVNC launcher
│   ├── process-respawner.py # Process revival daemon
│   └── openbox-rc.xml      # Window manager config
├── patches/
│   └── add-sudo-cheat.sh   # Patch for sudo cheat code
├── wad/
│   ├── psdoom1.wad         # Process level data
│   └── psdoom2.wad         # Additional level data
└── archive/
    ├── legacy-vm/          # Old QEMU-based approach (deprecated)
    └── psdoom-2000.05.03-patch  # Historical XDoom patch
```

---

## Development History

### Phase 1: QEMU Virtual Machine

The original approach used QEMU to run a full Linux VM with psDoom. This required:
- Downloading QEMU binaries
- Creating cloud-init ISOs
- Managing VM networking
- Complex PowerShell/Bash scripts

**Problems**: Slow startup, high resource usage, complex setup, Windows compatibility issues.

### Phase 2: Docker Container

Migrated to a Docker-based approach with noVNC for browser access:
- Single container instead of full VM
- HTML5 interface - no VNC client needed
- Cross-platform compatibility
- Simple `./run.sh` to start

### Phase 3: Engine Replacement

Replaced XDoom-based psDoom with psDoom-ng (Chocolate Doom):
- Fixed crashes and instability
- Modern 64-bit build
- Better graphics handling
- Maintained process-killing functionality

### Phase 4: Custom Features

Added Fight the Machine exclusives:
- `sudo` cheat code (god mode + full arsenal)
- Process respawner for endless gameplay
- Optimized display settings

---

## Credits

- **Dennis Chao** - Original psDoom concept (1999)
- **Orson Teodoro** - psDoom-ng Chocolate Doom port
- **Chocolate Doom Team** - Vanilla-accurate source port
- **noVNC Project** - HTML5 VNC client
- **id Software** - DOOM (1993)

---

*For the glory of /proc*
