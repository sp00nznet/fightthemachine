# psDoom Docker - Documentation

## Architecture

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

**Components:**
1. **Xvfb** - Virtual X11 framebuffer
2. **psDoom** - The game running on the virtual display
3. **x11vnc** - Captures display as VNC stream
4. **noVNC** - Converts VNC to HTML5 WebSocket
5. **Process Respawner** - Brings back killed processes

---

## Configuration

### Environment Variables

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

Or via command line:
```bash
docker run -e RESOLUTION=1920x1080 -p 6080:6080 psdoom
```

### Resource Limits

Default limits in `docker-compose.yml`:
- **CPU**: 2 cores
- **Memory**: 1GB

Adjust in docker-compose.yml:
```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 2G
```

---

## Process Respawner

Killed processes respawn after a delay based on their "enemy tier":

| Enemy Tier | Process Examples | Respawn Delay |
|------------|------------------|---------------|
| Zombieman | cat, sleep, echo | 5-10 seconds |
| Imp | vim, python, grep | 8-15 seconds |
| Demon | window managers | 12-20 seconds |
| Cacodemon | cron, networking | 15-25 seconds |
| Baron of Hell | init, X server | 20-30 seconds |

**View logs:**
```bash
docker exec psdoom tail -f /var/log/process-respawner.log
```

---

## Building Manually

```bash
# Build image
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

### Can't connect to http://localhost:6080

1. Check container status: `./run.sh status`
2. View logs: `./run.sh logs`
3. Wait ~30 seconds for startup
4. Try different browser

### Black screen in browser

1. Check Xvfb: `docker exec psdoom pgrep Xvfb`
2. Check psDoom logs: `docker exec psdoom cat /var/log/supervisor/psdoom.log`
3. Rebuild: `./run.sh build && ./run.sh start`

### psDoom crashes

1. Check error log: `docker exec psdoom cat /var/log/supervisor/psdoom.err`
2. Verify WAD file: `docker exec psdoom ls -la /home/doom/.psdoom/`
3. Run manually: `docker exec -it psdoom /usr/local/bin/psdoom -iwad /home/doom/.psdoom/DOOM1.WAD`

### VNC client won't connect

VNC is passwordless by default. To set a password:
```bash
docker exec psdoom x11vnc -storepasswd yourpassword /tmp/vncpass
```

---

## File Structure

```
fightthemachine/
├── Dockerfile              # Container build
├── docker-compose.yml      # Compose config
├── run.sh                  # Linux/Mac script
├── run.bat                 # Windows script
├── docker/
│   ├── supervisord.conf    # Process manager
│   ├── start-psdoom.sh     # Game launcher
│   ├── start-vnc.sh        # VNC launcher
│   ├── process-respawner.py
│   └── openbox-rc.xml      # Window manager
├── archive/
│   └── legacy-vm/          # Old QEMU-based scripts
├── README.md
└── DOCUMENTATION.md
```

---

## How psDoom Works

psDoom maps running processes to DOOM monsters:

- **Zombieman** = Trivial processes (cat, sleep)
- **Imp** = User apps (vim, python)
- **Demon** = Desktop processes
- **Cacodemon** = System daemons
- **Baron of Hell** = Critical services

**Killing a monster = `kill -9` on the process**

Processes are only killed inside the container, not on your host.

---

## Credits

- [psDoom](https://github.com/sp00nznet/psdoom-src) - Dennis Chao (original), orsonteodoro (updates)
- [noVNC](https://novnc.com/) - HTML5 VNC client
- [Docker](https://www.docker.com/)
- [id Software](https://www.idsoftware.com/) - DOOM
