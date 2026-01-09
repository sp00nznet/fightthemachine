# psDoom Docker

> Kill processes as DOOM monsters - in your browser.

Run [psDoom](https://github.com/sp00nznet/psdoom-src) in a Docker container with HTML5 browser access.

## Quick Start

```bash
./run.sh
# Open http://localhost:6080
```

**Windows:** Run `run.bat` then open http://localhost:6080

## Requirements

- Docker with Docker Compose
- A web browser

## Controls

| Key | Action |
|-----|--------|
| Arrow keys | Move |
| Ctrl | Fire |
| Space | Use/Open |
| Tab | Process map |
| Esc | Menu |

## Commands

```bash
./run.sh start    # Start container (default)
./run.sh stop     # Stop container
./run.sh logs     # View logs
./run.sh status   # Check status
```

## Ports

| Port | Description |
|------|-------------|
| 6080 | HTML5 web interface |
| 5900 | VNC (optional) |

## Documentation

See [DOCUMENTATION.md](DOCUMENTATION.md) for detailed configuration, troubleshooting, and architecture info.

## License

Public domain. psDoom is GPL. DOOM WAD is shareware.

---

*RIP AND TEAR*
