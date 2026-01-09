# psDoom Docker

> Kill processes. Not demons. In your browser.

Run [psDoom](https://github.com/sp00nznet/psdoom-src) in a Docker container with HTML5 browser access. No VM, no QEMU, no X11 forwarding - just open your browser and start killing processes.

---

## Quick Start

```bash
# Clone and run
git clone https://github.com/sp00nznet/fightthemachine.git
cd fightthemachine
./run.sh

# Open in browser
open http://localhost:6080
```

**Windows:**
```batch
git clone https://github.com/sp00nznet/fightthemachine.git
cd fightthemachine
run.bat

:: Open http://localhost:6080 in your browser
```

---

## Requirements

- **Docker** with Docker Compose
- **~1GB disk space** for the container image
- A modern web browser

That's it. Everything else is containerized.

---

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│                    Your Browser                          │
│                  http://localhost:6080                   │
└─────────────────────┬───────────────────────────────────┘
                      │ HTML5 WebSocket
                      ▼
┌─────────────────────────────────────────────────────────┐
│                  Docker Container                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   noVNC     │──│   x11vnc    │──│    Xvfb     │     │
│  │  (HTML5)    │  │ (VNC server)│  │ (Virtual X) │     │
│  └─────────────┘  └─────────────┘  └──────┬──────┘     │
│                                           │             │
│  ┌─────────────┐                   ┌──────┴──────┐     │
│  │  Process    │                   │   psDoom    │     │
│  │  Respawner  │◄──────────────────│   (game)    │     │
│  └─────────────┘   kills processes └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```

1. **Xvfb** creates a virtual X11 display
2. **psDoom** runs fullscreen on that display
3. **x11vnc** captures the display as VNC
4. **noVNC** converts VNC to HTML5 WebSocket
5. **Your browser** renders the game
6. **Process Respawner** brings back killed processes (like DOOM enemies!)

---

## Usage

### Run Commands

```bash
./run.sh start    # Build and start (default)
./run.sh stop     # Stop the container
./run.sh restart  # Restart the container
./run.sh logs     # View container logs
./run.sh status   # Check container status
./run.sh build    # Rebuild the image
./run.sh shell    # Open a shell in the container
```

### Docker Compose

```bash
# Start in foreground (see logs)
docker compose up

# Start in background
docker compose up -d

# Stop
docker compose down

# Rebuild
docker compose up -d --build
```

### Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 6080 | HTTP | HTML5 web interface (primary) |
| 5900 | VNC | Direct VNC access (optional) |

---

## Game Controls

### Browser Controls

- **Click** anywhere to capture mouse
- **Esc** to release mouse

### psDoom Controls

| Keys | Action |
|------|--------|
| Arrow keys | Move |
| `Ctrl` | Fire |
| `Space` | Use/Open doors |
| `1-7` | Select weapon |
| `Tab` | Show process map |
| `Esc` | Menu |

### What psDoom Does

psDoom replaces DOOM monsters with your container's running processes:

- **Zombieman** = Trivial processes (cat, sleep, echo)
- **Imp** = User apps (vim, python, grep)
- **Demon** = Desktop processes (window managers)
- **Cacodemon** = System daemons (cron, networking)
- **Baron of Hell** = Critical services (init, display server)

**Killing a monster = Killing the process (`kill -9`)**

Don't worry - it only kills processes *inside the container*, not on your host.

---

## Process Respawner

The container includes a **Process Respawner Daemon** - killed processes come back after a delay, just like DOOM enemies!

**Respawn delays by enemy tier:**

| Enemy Tier | Process Type | Respawn Delay |
|------------|--------------|---------------|
| Zombieman | Trivial (cat, sleep) | 5-10 seconds |
| Imp | User apps (vim, python) | 8-15 seconds |
| Demon | Desktop components | 12-20 seconds |
| Cacodemon | System daemons | 15-25 seconds |
| Baron of Hell | Critical services | 20-30 seconds |

The harder the enemy, the longer before it respawns!

**View respawner logs:**
```bash
docker exec psdoom tail -f /var/log/process-respawner.log
```

---

## Configuration

### Environment Variables

Set in `docker-compose.yml` or via command line:

| Variable | Default | Description |
|----------|---------|-------------|
| `RESOLUTION` | `1024x768` | Display resolution |
| `VNC_PORT` | `5900` | VNC server port |
| `NOVNC_PORT` | `6080` | noVNC web port |

### Custom Resolution

```yaml
# docker-compose.yml
services:
  psdoom:
    environment:
      - RESOLUTION=1920x1080
```

Or:

```bash
docker run -e RESOLUTION=1920x1080 -p 6080:6080 psdoom
```

### Resource Limits

Default limits in `docker-compose.yml`:
- **CPU**: 2 cores
- **Memory**: 1GB

Adjust as needed:

```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 2G
```

---

## Building Manually

```bash
# Build the image
docker build -t psdoom .

# Run without compose
docker run -d \
  --name psdoom \
  -p 6080:6080 \
  -p 5900:5900 \
  --cap-add SYS_PTRACE \
  psdoom
```

---

## Troubleshooting

### "Can't connect to http://localhost:6080"

1. Check if container is running: `./run.sh status`
2. Check logs: `./run.sh logs`
3. Wait ~30 seconds for full startup
4. Try a different browser

### "Black screen in browser"

1. Check if Xvfb started: `docker exec psdoom pgrep Xvfb`
2. Check psDoom logs: `docker exec psdoom cat /var/log/supervisor/psdoom.log`
3. Rebuild: `./run.sh build && ./run.sh start`

### "psDoom crashes / exits"

1. Check logs: `docker exec psdoom cat /var/log/supervisor/psdoom.err`
2. Verify WAD file exists: `docker exec psdoom ls -la /home/doom/.psdoom/`
3. Try running manually: `docker exec -it psdoom /usr/local/bin/psdoom -iwad /home/doom/.psdoom/DOOM1.WAD`

### "VNC client won't connect to port 5900"

VNC is passwordless by default. If your client requires a password, set one:

```bash
docker exec psdoom x11vnc -storepasswd yourpassword /tmp/vncpass
# Then restart the container
```

---

## Files

```
fightthemachine/
├── Dockerfile              # Container build instructions
├── docker-compose.yml      # Compose configuration
├── run.sh                  # Linux/Mac helper script
├── run.bat                 # Windows helper script
├── docker/
│   ├── supervisord.conf    # Process manager config
│   ├── start-psdoom.sh     # psDoom launcher
│   ├── start-vnc.sh        # VNC server launcher
│   ├── process-respawner.py# Respawn daemon
│   └── openbox-rc.xml      # Window manager config
└── README.md               # This file
```

---

## Legacy VM Scripts

The original QEMU-based VM scripts are still available:

| File | Description |
|------|-------------|
| `Install-psDoomKiosk.ps1` | Interactive Windows installer |
| `psdoom-kiosk.ps1` | Full ISO installation |
| `psdoom-kiosk-quick.ps1` | Quick cloud image install |

These create a full Debian VM with XFCE desktop. Use the Docker version instead for simpler deployment.

---

## Credits

- [psDoom](https://github.com/sp00nznet/psdoom-src) by Dennis Chao (original), orsonteodoro (updates)
- [noVNC](https://novnc.com/) - HTML5 VNC client
- [Docker](https://www.docker.com/) - containerization
- [id Software](https://www.idsoftware.com/) - for DOOM

---

## License

These scripts are public domain. Do whatever you want.

psDoom is GPL. DOOM shareware WAD is freely distributable.

---

*RIP AND TEAR, UNTIL IT IS DONE.*
