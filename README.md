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

> **Kill processes as DOOM monsters - in your browser.**

Fight the Machine runs [psDoom-ng](https://github.com/orsonteodoro/psdoom-ng) in a Docker container with HTML5 browser access. No installation required - just Docker and a web browser.

---

## Quick Start

```bash
# Linux/Mac
./run.sh
```

```batch
# Windows
run.bat
```

**Windows (Native App):** Build and run the [Win32 client](win32/) for a native desktop experience.

Then open **http://localhost:6080** in your browser.

---

## How It Works

Every running process in the container becomes a DOOM monster. **Kill the monster = kill the process.**

| Monster | Process Type | Example |
|---------|--------------|---------|
| Zombieman | Trivial processes | `cat`, `sleep`, `echo` |
| Imp | User applications | `vim`, `python`, `grep` |
| Demon | Desktop processes | Window managers |
| Cacodemon | System daemons | `cron`, networking |
| Baron of Hell | Critical services | `init`, X server |

Processes only die inside the container - your host system is completely safe.

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

---

## Cheat Codes

Just like the original DOOM, you can type cheat codes during gameplay:

| Cheat | Effect |
|-------|--------|
| `iddqd` | God mode (invincibility) |
| `idkfa` | All weapons, ammo, and keys |
| `idfa` | All weapons and ammo (no keys) |
| `idclip` | No-clip (walk through walls) |
| `iddt` | Reveal map (press twice for full reveal) |
| **`sudo`** | **God mode + full arsenal** (IDDQD + IDKFA combined) |

The `sudo` cheat is a Fight the Machine exclusive - because in Unix, `sudo` gives you root powers.

---

## Commands

```bash
./run.sh start    # Start the container (default)
./run.sh stop     # Stop the container
./run.sh restart  # Restart the container
./run.sh logs     # View container logs
./run.sh status   # Check if running
./run.sh build    # Rebuild the image
```

---

## Requirements

- **Docker** with Docker Compose
- A modern **web browser**
- That's it.

---

## Ports

| Port | Description |
|------|-------------|
| `6080` | HTML5 web interface (noVNC) |
| `5900` | VNC direct access (optional) |

---

## Win32 Native Client

A native Windows desktop application is available in the `win32/` directory. It embeds WebView2 and manages the Docker container automatically.

```batch
cd win32
build.bat release
```

See [win32/README.md](win32/README.md) for build instructions.

---

## Repositories

- **GitHub:** https://github.com/sp00nznet/fightthemachine
- **GitLab:** https://buildforever.cloud/sp00nz/fightthemachine

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Your Browser                            │
│                     http://localhost:6080                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │ WebSocket
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

---

## Technical Details

### Engine: psDoom-ng

Fight the Machine uses **psDoom-ng**, a modern port based on **Chocolate Doom**. This replaced the original XDoom-based psDoom client for several reasons:

| Feature | Original psDoom (XDoom) | psDoom-ng (Chocolate Doom) |
|---------|------------------------|---------------------------|
| Stability | Frequent crashes | Rock solid |
| Compatibility | 32-bit only, old libs | Modern 64-bit systems |
| Accuracy | Modified behavior | Vanilla DOOM accurate |
| Maintenance | Abandoned (2000) | Actively maintained |

The migration involved resolving build issues, WAD compatibility, and display scaling - all handled automatically by the Docker build.

### Process Respawner

Killed processes respawn after a delay based on their enemy tier:

| Enemy Tier | Respawn Delay |
|------------|---------------|
| Zombieman | 5-10 seconds |
| Imp | 8-15 seconds |
| Demon | 12-20 seconds |
| Cacodemon | 15-25 seconds |
| Baron of Hell | 20-30 seconds |

This keeps the game interesting - you can never truly "win" against the machine.

---

## Documentation

See [DOCUMENTATION.md](DOCUMENTATION.md) for:
- Configuration options
- Environment variables
- Troubleshooting guide
- Manual build instructions

---

## Credits

- **[psDoom](http://psdoom.sourceforge.net/)** - Dennis Chao (original 1999)
- **[psDoom-ng](https://github.com/orsonteodoro/psdoom-ng)** - Orson Teodoro (Chocolate Doom port)
- **[Chocolate Doom](https://www.chocolate-doom.org/)** - Vanilla DOOM source port
- **[noVNC](https://novnc.com/)** - HTML5 VNC client
- **[id Software](https://www.idsoftware.com/)** - DOOM (1993)

---

## License

This project is public domain. The game engine (psDoom-ng/Chocolate Doom) is GPL. DOOM WAD is shareware.

---

<p align="center">
  <i>RIP AND TEAR, UNTIL IT IS DONE.</i>
</p>
