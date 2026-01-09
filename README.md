# psDoom Kiosk

> Kill processes. Not demons. In a VM.

Automated setup for a **psDoom kiosk VM** on Windows. Creates a minimal Debian virtual machine that boots directly into [psDoom](https://github.com/sp00nznet/psdoom-src) - the classic DOOM mod where you kill your system processes instead of demons.

---

## Quick Start

1. **Right-click** `Install-psDoomKiosk.ps1` -> **Run with PowerShell**
2. Select **[1] New Installation**
3. Choose **[1] Quick Install** (recommended)
4. Wait ~10-15 minutes
5. Done! The VM boots straight into psDoom

---

## What's Included

| File | Description |
|------|-------------|
| `Install-psDoomKiosk.ps1` | Interactive menu-driven installer |
| `psdoom-kiosk.ps1` | Full installation (Debian ISO + preseed) |
| `psdoom-kiosk-quick.ps1` | Quick installation (Debian cloud image) |
| `README.md` | This file |

---

## Requirements

- **Windows 10/11** (64-bit)
- **~25GB free disk space** (for QEMU + VM)
- **Internet connection** (for downloads)
- **Administrator access** (recommended, not required)

Everything else is downloaded automatically:
- QEMU for Windows
- Debian 12 (Bookworm)
- psDoom source code
- Shareware DOOM WAD

---

## Features

### Logging

All scripts create detailed logs in `%USERPROFILE%\psdoom-kiosk\logs\`:
- `installer-YYYYMMDD-HHMMSS.log` - Interactive installer logs
- `install-quick-YYYYMMDD-HHMMSS.log` - Quick install logs
- `install-full-YYYYMMDD-HHMMSS.log` - Full install logs

Access logs via:
- Menu option **[4] View Logs**
- Desktop shortcut **psDoom Kiosk - View Logs**

### Desktop Shortcuts

After installation, these shortcuts are created:
- **psDoom Kiosk** - Launch the VM
- **psDoom Kiosk - Open Folder** - Open installation directory
- **psDoom Kiosk - View Logs** - Open logs folder

A Start Menu shortcut is also created.

---

## Installation Methods

### Quick Install (Recommended)

Uses a Debian **cloud image** with cloud-init for configuration.

- Smaller download (~700MB)
- Faster setup (~10-15 min)
- Fully automated

### Full Install

Uses the Debian **netinst ISO** with preseed automation.

- Traditional OS installation
- More customizable
- Longer setup (~20-30 min)

---

## Usage

### Interactive Mode

```powershell
.\Install-psDoomKiosk.ps1
```

Opens a menu with options to:
1. Install new VM
2. Start existing VM
3. Configure settings
4. View logs
5. Uninstall

### Command Line

```powershell
# Quick install with defaults
.\psdoom-kiosk-quick.ps1

# Full install with custom settings
.\psdoom-kiosk.ps1 -VMMemoryMB 4096 -VMCores 4 -VMDiskGB 30

# Start existing VM
.\psdoom-kiosk.ps1 -StartOnly

# Non-interactive install
.\Install-psDoomKiosk.ps1 -NonInteractive -Method Quick
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-InstallPath` | `%USERPROFILE%\psdoom-kiosk` | Installation directory |
| `-VMMemoryMB` | `2048` | VM RAM in megabytes |
| `-VMCores` | `2` | VM CPU cores |
| `-VMDiskGB` | `20` | VM disk size in gigabytes |
| `-StartOnly` | - | Skip install, just launch VM |
| `-SkipQEMUInstall` | - | Don't install QEMU |

---

## After Installation

### Starting the Kiosk

Use any of these methods:
- Desktop shortcut **psDoom Kiosk**
- Run `Install-psDoomKiosk.ps1` -> **[2] Start Existing VM**
- Double-click `Start-psDoom.bat` in the install folder

### QEMU Controls

| Keys | Action |
|------|--------|
| `Ctrl+Alt+G` | Release mouse from VM |
| `Ctrl+Alt+F` | Toggle fullscreen |
| `Ctrl+Alt+Q` | Quit QEMU |

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

psDoom replaces DOOM monsters with your actual running processes:
- **Imps** = Low-priority processes
- **Demons** = Medium-priority processes  
- **Barons** = High-priority processes
- **Killing a monster** = Kills the process (`kill -9`)

**Warning**: This runs inside the VM, so it kills *VM* processes, not your host machine. Still, be careful - killing the wrong process can crash the VM.

### Process Respawner (The Demons Keep Coming Back!)

The VM includes a **Process Respawner Daemon** that monitors killed processes and respawns them after a delay. Just like in DOOM, the enemies keep coming back!

**Respawn delays are based on enemy difficulty:**

| Enemy Tier | Process Type | Respawn Delay |
|------------|--------------|---------------|
| Zombieman | Trivial (cat, sleep, echo) | 5-10 seconds |
| Imp | User apps (vim, python, grep) | 8-15 seconds |
| Demon | Desktop (xfce4, thunar, pulseaudio) | 12-20 seconds |
| Cacodemon | System daemons (cron, NetworkManager) | 15-25 seconds |
| Baron of Hell | Critical services (systemd, Xorg, lightdm) | 20-30 seconds |

The harder the enemy, the longer it takes to respawn!

**Respawner logs**: `/var/log/process-respawner.log`

**Manage the respawner**:
```bash
# Check status
systemctl status process-respawner

# Stop respawning (easy mode)
systemctl stop process-respawner

# Restart respawner
systemctl restart process-respawner

# View respawner logs
tail -f /var/log/process-respawner.log
```

---

## File Locations

After installation:

```
%USERPROFILE%\psdoom-kiosk\
|-- logs\                      # Installation and runtime logs
|   |-- installer-*.log
|   |-- install-quick-*.log
|   +-- install-full-*.log
|-- psdoom-disk.qcow2          # VM disk image
|-- debian-12-cloud.qcow2      # Base image (Quick install)
|-- debian-12-netinst.iso      # ISO (Full install)
|-- cloud-init-data\           # Cloud-init config
|-- Start-psDoom.bat           # Quick launcher
+-- Start-psDoom.ps1           # PowerShell launcher
```

QEMU is installed to `C:\Program Files\qemu\`

---

## Troubleshooting

### Check the Logs First!

Most issues can be diagnosed from the logs:
1. Run installer -> **[4] View Logs**
2. Open the most recent `.log` file
3. Search for `[ERROR]` or `[WARN]` entries

### "QEMU installation failed"

- Run as Administrator
- Check antivirus isn't blocking the installer
- Check logs for specific error
- Manually download from [qemu.weilnetz.de](https://qemu.weilnetz.de/w64/)

### "VM won't start"

- Ensure Hyper-V is disabled (conflicts with QEMU)
- Check if another VM is using the disk file
- Try increasing memory (`-VMMemoryMB 4096`)
- Check logs for QEMU errors

### "psDoom doesn't start after boot"

The first boot takes time to:
1. Run cloud-init
2. Install packages
3. Clone and build psDoom
4. Download the WAD file

Wait for the VM to reboot automatically. If it's stuck:

```bash
# SSH into VM (if networking works)
ssh doom@<vm-ip>  # password: psdoom

# Check build log
cat /home/doom/setup.log

# Check cloud-init status
cat /var/log/cloud-init-output.log

# Manually run setup
/home/doom/setup-psdoom.sh
```

### "No display / black screen"

- Try different display: add `-display gtk` to QEMU args
- Update graphics drivers on host
- Check logs for QEMU stderr

---

## Uninstalling

### Via Menu

Run `Install-psDoomKiosk.ps1` -> **[5] Uninstall**

This removes:
- VM disk and configuration
- Downloaded images/ISOs
- All shortcuts (Desktop and Start Menu)
- Log files

### Manually

```powershell
# Remove VM files
Remove-Item -Recurse "$env:USERPROFILE\psdoom-kiosk"

# Remove desktop shortcuts
Remove-Item "$env:USERPROFILE\Desktop\psDoom Kiosk*.lnk"

# (Optional) Uninstall QEMU via Control Panel
```

---

## How It Works

1. **Downloads QEMU** for Windows (hardware-accelerated x86 emulation)
2. **Downloads Debian** cloud image or netinst ISO
3. **Creates VM disk** (qcow2 format, grows as needed)
4. **Configures cloud-init/preseed** for automated setup:
   - Creates `doom` user with auto-login
   - Installs XFCE (minimal desktop)
   - Clones psDoom from GitHub
   - Builds from source (SDL 1.2)
   - Downloads shareware DOOM WAD
   - Sets psDoom as autostart application
5. **Creates shortcuts** on Desktop and Start Menu
6. **Boots into kiosk mode** - nothing but DOOM

---

## Credits

- [psDoom](https://github.com/sp00nznet/psdoom-src) by Dennis Chao (original), orsonteodoro (updates)
- [QEMU](https://www.qemu.org/) - the emulator
- [Debian](https://www.debian.org/) - the OS
- [id Software](https://www.idsoftware.com/) - for DOOM

---

## License

These scripts are public domain. Do whatever you want.

psDoom is GPL. DOOM shareware WAD is freely distributable.

---

*RIP AND TEAR, UNTIL IT IS DONE.*
