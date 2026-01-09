<#
.SYNOPSIS
    psDoom Kiosk - Full Installation (Debian ISO + Preseed)
    
.DESCRIPTION
    Downloads QEMU for Windows, creates a Debian VM using netinst ISO,
    and configures it to boot directly into psDoom.
    
.NOTES
    Run as Administrator for best results.
#>

#Requires -Version 5.1

param(
    [string]$InstallPath = "$env:USERPROFILE\psdoom-kiosk",
    [int]$VMMemoryMB = 2048,
    [int]$VMCores = 2,
    [int]$VMDiskGB = 20,
    [switch]$SkipQEMUInstall,
    [switch]$SkipVMCreate,
    [switch]$StartOnly
)

$ErrorActionPreference = "Stop"

# =============================================================================
# Logging Setup
# =============================================================================

$script:LogFile = $null

function Initialize-Logging {
    param([string]$BasePath)
    
    $logDir = Join-Path $BasePath "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:LogFile = Join-Path $logDir "install-full-$timestamp.log"
    
    # Write header
    $header = @"
================================================================================
psDoom Kiosk - Full Installation Log
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Host: $env:COMPUTERNAME
User: $env:USERNAME
PowerShell: $($PSVersionTable.PSVersion)
================================================================================

"@
    $header | Out-File -FilePath $script:LogFile -Encoding utf8
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    
    if ($script:LogFile) {
        $logLine | Out-File -FilePath $script:LogFile -Append -Encoding utf8
    }
    
    # Also write to console with color
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        "DEBUG"   { "DarkGray" }
    }
    
    Write-Host "[$Level] " -NoNewline -ForegroundColor $color
    Write-Host $Message
}

function Write-LogSection {
    param([string]$Title)
    
    $line = "=" * 60
    $section = "`n$line`n  $Title`n$line`n"
    
    if ($script:LogFile) {
        $section | Out-File -FilePath $script:LogFile -Append -Encoding utf8
    }
    
    Write-Host ""
    Write-Host $line -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host $line -ForegroundColor Cyan
    Write-Host ""
}

# =============================================================================
# Configuration
# =============================================================================

$Config = @{
    QEMUVersion     = "2024-02-17"
    QEMUDownloadUrl = "https://qemu.weilnetz.de/w64/2024/qemu-w64-setup-20240217.exe"
    QEMUInstallPath = "C:\Program Files\qemu"
    
    DebianISOUrl    = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.9.0-amd64-netinst.iso"
    DebianISOName   = "debian-12-netinst.iso"
    
    VMName          = "psdoom-kiosk"
    VMDiskName      = "psdoom-disk.qcow2"
    PreseedFile     = "preseed.cfg"
}

# =============================================================================
# Helper Functions
# =============================================================================

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-FileWithProgress {
    param(
        [string]$Url,
        [string]$OutFile
    )
    
    Write-Log "Downloading: $Url" -Level INFO
    Write-Log "Destination: $OutFile" -Level DEBUG
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        Start-BitsTransfer -Source $Url -Destination $OutFile -DisplayName "Downloading..." -ErrorAction Stop
    }
    catch {
        Write-Log "BITS transfer failed, falling back to WebRequest: $_" -Level WARN
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
        $ProgressPreference = 'Continue'
    }
    
    $stopwatch.Stop()
    
    if (Test-Path $OutFile) {
        $size = (Get-Item $OutFile).Length / 1MB
        Write-Log "Downloaded $([math]::Round($size, 2)) MB in $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1)) seconds" -Level SUCCESS
    }
}

# =============================================================================
# Shortcut Functions
# =============================================================================

function New-DesktopShortcut {
    param(
        [string]$Name,
        [string]$TargetPath,
        [string]$Arguments = "",
        [string]$WorkingDirectory = "",
        [string]$IconPath = "",
        [string]$Description = ""
    )
    
    try {
        $desktopPath = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktopPath "$Name.lnk"
        
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $TargetPath
        
        if ($Arguments) { $shortcut.Arguments = $Arguments }
        if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
        if ($IconPath) { $shortcut.IconLocation = $IconPath }
        if ($Description) { $shortcut.Description = $Description }
        
        $shortcut.Save()
        
        Write-Log "Created desktop shortcut: $shortcutPath" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Failed to create desktop shortcut: $_" -Level ERROR
        return $false
    }
}

function New-StartMenuShortcut {
    param(
        [string]$Name,
        [string]$TargetPath,
        [string]$Arguments = "",
        [string]$WorkingDirectory = ""
    )
    
    try {
        $startMenuPath = [Environment]::GetFolderPath("StartMenu")
        $programsPath = Join-Path $startMenuPath "Programs"
        $shortcutPath = Join-Path $programsPath "$Name.lnk"
        
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $TargetPath
        
        if ($Arguments) { $shortcut.Arguments = $Arguments }
        if ($WorkingDirectory) { $shortcut.WorkingDirectory = $WorkingDirectory }
        
        $shortcut.Save()
        
        Write-Log "Created Start Menu shortcut: $shortcutPath" -Level SUCCESS
        return $true
    }
    catch {
        Write-Log "Failed to create Start Menu shortcut: $_" -Level WARN
        return $false
    }
}

function New-AllShortcuts {
    param([string]$InstallPath)
    
    Write-LogSection "Creating Shortcuts"
    
    $batchPath = Join-Path $InstallPath "Start-psDoom.bat"
    $diskPath = Join-Path $InstallPath $Config.VMDiskName
    $qemuPath = Join-Path $Config.QEMUInstallPath "qemu-system-x86_64.exe"
    
    # Create batch launcher
    $batchContent = @"
@echo off
title psDoom Kiosk
echo Starting psDoom Kiosk...
echo.
echo Controls:
echo   Ctrl+Alt+G = Release mouse
echo   Ctrl+Alt+F = Toggle fullscreen
echo.
"$qemuPath" -name "psDoom-Kiosk" -m ${VMMemoryMB}M -smp cores=$VMCores -hda "$diskPath" -boot c -netdev user,id=net0 -device virtio-net-pci,netdev=net0 -vga virtio -display sdl -full-screen
"@
    $batchContent | Out-File -FilePath $batchPath -Encoding ascii
    Write-Log "Created batch launcher: $batchPath" -Level SUCCESS
    
    # Create PowerShell launcher
    $psLauncherPath = Join-Path $InstallPath "Start-psDoom.ps1"
    $psContent = @"
# psDoom Kiosk Launcher
`$qemu = "$qemuPath"
`$disk = "$diskPath"

Write-Host "Starting psDoom Kiosk..." -ForegroundColor Green
Write-Host "Controls: Ctrl+Alt+G = Release mouse, Ctrl+Alt+F = Fullscreen" -ForegroundColor Gray

& `$qemu ``
    -name "psDoom-Kiosk" ``
    -m ${VMMemoryMB}M ``
    -smp cores=$VMCores ``
    -hda `$disk ``
    -boot c ``
    -netdev user,id=net0 ``
    -device virtio-net-pci,netdev=net0 ``
    -vga virtio ``
    -display sdl ``
    -full-screen
"@
    $psContent | Out-File -FilePath $psLauncherPath -Encoding utf8
    Write-Log "Created PowerShell launcher: $psLauncherPath" -Level SUCCESS
    
    # Desktop shortcut
    New-DesktopShortcut -Name "psDoom Kiosk" `
        -TargetPath $batchPath `
        -WorkingDirectory $InstallPath `
        -Description "Launch psDoom Kiosk VM"
    
    # Start Menu shortcut
    New-StartMenuShortcut -Name "psDoom Kiosk" `
        -TargetPath $batchPath `
        -WorkingDirectory $InstallPath
    
    # Create "Open Install Folder" shortcut
    New-DesktopShortcut -Name "psDoom Kiosk - Open Folder" `
        -TargetPath "explorer.exe" `
        -Arguments $InstallPath `
        -Description "Open psDoom Kiosk installation folder"
}

# =============================================================================
# Installation Functions
# =============================================================================

function Install-QEMU {
    Write-LogSection "Installing QEMU for Windows"
    
    $qemuExe = Join-Path $Config.QEMUInstallPath "qemu-system-x86_64.exe"
    
    if (Test-Path $qemuExe) {
        Write-Log "QEMU already installed at: $($Config.QEMUInstallPath)" -Level SUCCESS
        return
    }
    
    $installerPath = Join-Path $InstallPath "qemu-setup.exe"
    
    if (-not (Test-Path $installerPath)) {
        Get-FileWithProgress -Url $Config.QEMUDownloadUrl -OutFile $installerPath
    } else {
        Write-Log "QEMU installer already downloaded" -Level INFO
    }
    
    Write-Log "Running QEMU installer (silent mode)..." -Level INFO
    
    $process = Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-Log "QEMU installation failed with exit code: $($process.ExitCode)" -Level ERROR
        throw "QEMU installation failed"
    }
    
    $env:Path = "$($Config.QEMUInstallPath);$env:Path"
    
    Write-Log "QEMU installed successfully" -Level SUCCESS
}

function Get-DebianISO {
    Write-LogSection "Downloading Debian ISO"
    
    $isoPath = Join-Path $InstallPath $Config.DebianISOName
    
    if (Test-Path $isoPath) {
        Write-Log "Debian ISO already exists: $isoPath" -Level SUCCESS
        return $isoPath
    }
    
    Get-FileWithProgress -Url $Config.DebianISOUrl -OutFile $isoPath
    
    return $isoPath
}

function New-PreseedConfig {
    Write-LogSection "Creating Preseed Configuration"
    
    $preseedPath = Join-Path $InstallPath $Config.PreseedFile
    
    $preseedContent = @'
# Debian Preseed - psDoom Kiosk
# Fully automated installation

d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us
d-i console-setup/ask_detect boolean false

d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string psdoom-kiosk
d-i netcfg/get_domain string local

d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

d-i clock-setup/utc boolean true
d-i time/zone string UTC
d-i clock-setup/ntp boolean true

d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

d-i passwd/root-login boolean false
d-i passwd/user-fullname string Doom Player
d-i passwd/username string doom
d-i passwd/user-password password psdoom
d-i passwd/user-password-again password psdoom
d-i user-setup/allow-password-weak boolean true

tasksel tasksel/first multiselect standard, xfce-desktop
d-i pkgsel/include string git build-essential libsdl1.2-dev libsdl-mixer1.2-dev libsdl-net1.2-dev wget unzip lightdm xorg sudo

d-i pkgsel/upgrade select full-upgrade
popularity-contest popularity-contest/participate boolean false

d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default

d-i preseed/late_command string \
    in-target bash -c 'echo "doom ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/doom'; \
    in-target chmod 440 /etc/sudoers.d/doom; \
    in-target mkdir -p /etc/lightdm/lightdm.conf.d; \
    in-target bash -c 'echo "[Seat:*]" > /etc/lightdm/lightdm.conf.d/50-autologin.conf'; \
    in-target bash -c 'echo "autologin-user=doom" >> /etc/lightdm/lightdm.conf.d/50-autologin.conf'; \
    in-target bash -c 'echo "autologin-user-timeout=0" >> /etc/lightdm/lightdm.conf.d/50-autologin.conf'; \
    in-target bash -c 'echo "user-session=xfce" >> /etc/lightdm/lightdm.conf.d/50-autologin.conf'; \
    in-target bash -c 'echo "@reboot root /home/doom/first-boot.sh" >> /etc/crontab'

d-i finish-install/reboot_in_progress note
'@
    
    $preseedContent | Out-File -FilePath $preseedPath -Encoding ascii -Force
    Write-Log "Preseed configuration created: $preseedPath" -Level SUCCESS
    
    # Create the first-boot script that will be served via HTTP
    $firstBootScript = @'
#!/bin/bash
# First boot setup script for psDoom Kiosk
exec > /var/log/psdoom-firstboot.log 2>&1
echo "=== First Boot Setup Started ==="
date

# Remove ourselves from crontab
sed -i '/first-boot.sh/d' /etc/crontab

# Build psDoom
cd /home/doom
sudo -u doom git clone https://github.com/sp00nznet/psdoom-src.git build
cd build/trunk
sudo -u doom ./configure
sudo -u doom make
mkdir -p /home/doom/psdoom
cp src/psdoom /home/doom/psdoom/
chown doom:doom /home/doom/psdoom/psdoom

# Get WAD
cd /home/doom/psdoom
wget -q https://archive.org/download/DoomsharewareDOOM1.WAD/DOOM1.WAD -O doom1.wad || \
wget -q https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad -O doom1.wad || true
chown doom:doom doom1.wad

# Cleanup build
rm -rf /home/doom/build

# Create psDoom launcher
cat > /home/doom/start-psdoom.sh << 'LAUNCHER'
#!/bin/bash
sleep 3
xset s off -dpms
cd /home/doom/psdoom
exec ./psdoom -fullscreen
LAUNCHER
chmod +x /home/doom/start-psdoom.sh
chown doom:doom /home/doom/start-psdoom.sh

# Create autostart
mkdir -p /home/doom/.config/autostart
cat > /home/doom/.config/autostart/psdoom.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=psDoom
Exec=/home/doom/start-psdoom.sh
Hidden=false
X-GNOME-Autostart-enabled=true
DESKTOP
chown -R doom:doom /home/doom/.config

# Install process respawner
cat > /usr/local/bin/process-respawner.py << 'RESPAWNER'
#!/usr/bin/env python3
"""Process Respawner Daemon for psDoom - Respawns killed processes like DOOM enemies"""
import subprocess, time, random, os, sys, signal, threading, logging
from datetime import datetime

LOG_FILE = "/var/log/process-respawner.log"
logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[logging.FileHandler(LOG_FILE), logging.StreamHandler()])
log = logging.getLogger("respawner")

PROCESS_TIERS = {
    "zombieman": {"delay_range": (5, 10), "patterns": ["cat", "sleep", "yes", "echo", "head", "tail", "wc", "sort"]},
    "imp": {"delay_range": (8, 15), "patterns": ["vim", "nano", "less", "top", "htop", "ps", "grep", "python", "node"]},
    "demon": {"delay_range": (12, 20), "patterns": ["xfce4", "xfwm", "thunar", "pulseaudio", "dbus-daemon"]},
    "cacodemon": {"delay_range": (15, 25), "patterns": ["cron", "rsyslog", "NetworkManager", "avahi", "cups"]},
    "baron": {"delay_range": (20, 30), "patterns": ["systemd", "dbus", "lightdm", "Xorg", "sshd"]}
}
BLACKLIST = ["psdoom", "doom", "respawner", "bash", "sh", "apt", "dpkg", "systemctl", "kill", "reboot"]
SYSTEMD_SERVICES = {"cron": "cron", "rsyslog": "rsyslog", "NetworkManager": "NetworkManager", "lightdm": "lightdm"}

class ProcessMonitor:
    def __init__(self):
        self.tracked, self.queue, self.running, self.lock = {}, [], True, threading.Lock()
    
    def get_tier(self, name):
        for tier, info in PROCESS_TIERS.items():
            if any(p in name.lower() for p in info["patterns"]): return tier, info["delay_range"]
        return "imp", (8, 15)
    
    def get_procs(self):
        procs = {}
        try:
            r = subprocess.run(["ps", "-eo", "pid,comm,args", "--no-headers"], capture_output=True, text=True, timeout=5)
            for line in r.stdout.strip().split('\n'):
                if line.strip():
                    p = line.split(None, 2)
                    if len(p) >= 2: procs[int(p[0])] = {"name": p[1], "cmd": p[2] if len(p) > 2 else p[1]}
        except: pass
        return procs
    
    def snapshot(self):
        with self.lock:
            for pid, info in self.get_procs().items():
                if pid not in self.tracked and not any(b in info["name"].lower() for b in BLACKLIST):
                    tier, dr = self.get_tier(info["name"])
                    self.tracked[pid] = {"name": info["name"], "cmd": info["cmd"], "tier": tier, "dr": dr}
        log.info(f"Tracking {len(self.tracked)} processes")
    
    def check_deaths(self):
        curr = set(self.get_procs().keys())
        with self.lock:
            for pid in set(self.tracked.keys()) - curr:
                p = self.tracked.pop(pid)
                delay = random.uniform(*p["dr"])
                log.warning(f"KILLED: {p['name']} (PID {pid}) [{p['tier'].upper()}] - Respawn in {delay:.1f}s")
                self.queue.append((time.time() + delay, p))
    
    def process_queue(self):
        now = time.time()
        with self.lock:
            waiting = []
            for rt, p in self.queue:
                if now >= rt: self.respawn(p)
                else: waiting.append((rt, p))
            self.queue = waiting
    
    def respawn(self, p):
        log.info(f"RESPAWNING: {p['name']} [{p['tier'].upper()}]")
        try:
            if p["name"] in SYSTEMD_SERVICES:
                subprocess.run(["systemctl", "start", SYSTEMD_SERVICES[p["name"]]], timeout=10)
            else:
                subprocess.Popen([p["name"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except Exception as e: log.error(f"Failed: {e}")
    
    def run(self):
        log.info("Process Respawner Starting - The demons will keep coming back...")
        time.sleep(5); self.snapshot()
        while self.running:
            try:
                self.check_deaths(); self.process_queue()
                if random.random() < 0.1: self.snapshot()
                time.sleep(1)
            except Exception as e: log.error(f"Error: {e}"); time.sleep(5)
    def stop(self): self.running = False

monitor = ProcessMonitor()
signal.signal(signal.SIGTERM, lambda *_: (monitor.stop(), sys.exit(0)))
signal.signal(signal.SIGINT, lambda *_: (monitor.stop(), sys.exit(0)))
if __name__ == "__main__": monitor.run()
RESPAWNER
chmod +x /usr/local/bin/process-respawner.py

# Create systemd service
cat > /etc/systemd/system/process-respawner.service << 'SERVICE'
[Unit]
Description=psDoom Process Respawner Daemon
After=multi-user.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/process-respawner.py
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable process-respawner.service
systemctl start process-respawner.service

echo "=== First Boot Setup Complete ==="
date
'@
    $firstBootPath = Join-Path $InstallPath "first-boot.sh"
    $firstBootScript | Out-File -FilePath $firstBootPath -Encoding ascii -Force
    Write-Log "Created first-boot script: $firstBootPath" -Level SUCCESS
    
    return $preseedPath
}

function New-VMDisk {
    Write-LogSection "Creating VM Disk"
    
    $diskPath = Join-Path $InstallPath $Config.VMDiskName
    
    if (Test-Path $diskPath) {
        Write-Log "Disk already exists: $diskPath" -Level WARN
        $response = Read-Host "Delete and recreate? (y/N)"
        if ($response -eq 'y') {
            Remove-Item $diskPath -Force
            Write-Log "Deleted existing disk" -Level INFO
        } else {
            return $diskPath
        }
    }
    
    $qemuImg = Join-Path $Config.QEMUInstallPath "qemu-img.exe"
    
    Write-Log "Creating ${VMDiskGB}GB qcow2 disk..." -Level INFO
    $result = & $qemuImg create -f qcow2 $diskPath "${VMDiskGB}G" 2>&1
    Write-Log "qemu-img output: $result" -Level DEBUG
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to create disk image" -Level ERROR
        throw "Failed to create disk image"
    }
    
    Write-Log "Disk created: $diskPath" -Level SUCCESS
    return $diskPath
}

function Start-VMInstall {
    param(
        [string]$ISOPath,
        [string]$DiskPath,
        [string]$PreseedPath
    )
    
    Write-LogSection "Starting Debian Installation"
    
    $qemu = Join-Path $Config.QEMUInstallPath "qemu-system-x86_64.exe"
    
    Write-Log "ISO: $ISOPath" -Level DEBUG
    Write-Log "Disk: $DiskPath" -Level DEBUG
    Write-Log "Preseed: $PreseedPath" -Level DEBUG
    
    # Try to serve preseed via Python
    $preseedUrl = $null
    $pythonProcess = $null
    
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($python) {
        Write-Log "Starting HTTP server for preseed file..." -Level INFO
        $preseedDir = Split-Path $PreseedPath -Parent
        $pythonProcess = Start-Process -FilePath python -ArgumentList "-m", "http.server", "8888", "--directory", $preseedDir -WindowStyle Hidden -PassThru
        Start-Sleep -Seconds 2
        $preseedUrl = "http://10.0.2.2:8888/$($Config.PreseedFile)"
        Write-Log "Preseed URL: $preseedUrl" -Level SUCCESS
    } else {
        Write-Log "Python not found - manual installation required" -Level WARN
    }
    
    $qemuArgs = @(
        "-name", "psDoom-Kiosk-Install"
        "-m", "${VMMemoryMB}M"
        "-smp", "cores=$VMCores"
        "-hda", $DiskPath
        "-cdrom", $ISOPath
        "-boot", "d"
        "-netdev", "user,id=net0"
        "-device", "virtio-net-pci,netdev=net0"
        "-vga", "virtio"
        "-display", "sdl"
    )
    
    Write-Log "Starting QEMU for installation..." -Level INFO
    Write-Log "QEMU args: $($qemuArgs -join ' ')" -Level DEBUG
    
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Yellow
    Write-Host "  INSTALLATION IN PROGRESS" -ForegroundColor Yellow
    Write-Host "=" * 60 -ForegroundColor Yellow
    Write-Host ""
    
    if (-not $preseedUrl) {
        Write-Host "  MANUAL STEPS REQUIRED:" -ForegroundColor Cyan
        Write-Host "  1. Select 'Install' (not graphical install)"
        Write-Host "  2. Follow prompts (use defaults where possible)"
        Write-Host "  3. Create user 'doom' with password 'psdoom'"
        Write-Host "  4. Select 'XFCE' desktop environment"
        Write-Host "  5. Wait for installation to complete"
    } else {
        Write-Host "  Automated installation in progress..." -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "  When the VM reboots, close QEMU and run:" -ForegroundColor Yellow
    Write-Host "  .\psdoom-kiosk.ps1 -StartOnly" -ForegroundColor Cyan
    Write-Host ""
    
    $qemuProcess = Start-Process -FilePath $qemu -ArgumentList $qemuArgs -PassThru
    $qemuProcess.WaitForExit()
    
    if ($pythonProcess) {
        Stop-Process -Id $pythonProcess.Id -Force -ErrorAction SilentlyContinue
        Write-Log "Stopped preseed HTTP server" -Level DEBUG
    }
    
    Write-Log "QEMU exited with code: $($qemuProcess.ExitCode)" -Level INFO
}

function Start-VMKiosk {
    param([string]$DiskPath)
    
    Write-LogSection "Starting psDoom Kiosk"
    
    if (-not (Test-Path $DiskPath)) {
        Write-Log "VM disk not found: $DiskPath" -Level ERROR
        throw "VM disk not found: $DiskPath"
    }
    
    $qemu = Join-Path $Config.QEMUInstallPath "qemu-system-x86_64.exe"
    
    $qemuArgs = @(
        "-name", "psDoom-Kiosk"
        "-m", "${VMMemoryMB}M"
        "-smp", "cores=$VMCores"
        "-hda", $DiskPath
        "-boot", "c"
        "-netdev", "user,id=net0"
        "-device", "virtio-net-pci,netdev=net0"
        "-vga", "virtio"
        "-display", "sdl"
        "-full-screen"
    )
    
    Write-Log "Launching psDoom kiosk..." -Level INFO
    Write-Host ""
    Write-Host "  Controls:" -ForegroundColor Gray
    Write-Host "    Ctrl+Alt+G = Release mouse"
    Write-Host "    Ctrl+Alt+F = Toggle fullscreen"
    Write-Host ""
    
    Start-Process -FilePath $qemu -ArgumentList $qemuArgs
    
    Write-Log "psDoom kiosk is running!" -Level SUCCESS
}

# =============================================================================
# Main
# =============================================================================

function Main {
    Write-Host ""
    Write-Host "  ____  _____ ____   ___   ___  __  __ " -ForegroundColor Red
    Write-Host " |  _ \/ ____|  _ \ / _ \ / _ \|  \/  |" -ForegroundColor Red
    Write-Host " | |_) \___ \| | | | | | | | | | |\/| |" -ForegroundColor Red
    Write-Host " |  __/ ___) | |_| | |_| | |_| | |  | |" -ForegroundColor Red
    Write-Host " |_|   |____/|____/ \___/ \___/|_|  |_|" -ForegroundColor Red
    Write-Host "              KIOSK (Full Install)      " -ForegroundColor DarkRed
    Write-Host ""
    
    # Create install directory
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    
    # Initialize logging
    Initialize-Logging -BasePath $InstallPath
    
    Write-Log "psDoom Kiosk Full Installation starting..." -Level INFO
    Write-Log "Install path: $InstallPath" -Level INFO
    Write-Log "VM specs: ${VMMemoryMB}MB RAM, $VMCores cores, ${VMDiskGB}GB disk" -Level INFO
    
    # Check admin
    if (-not (Test-Administrator)) {
        Write-Log "Not running as Administrator - some features may not work" -Level WARN
    } else {
        Write-Log "Running as Administrator" -Level SUCCESS
    }
    
    $diskPath = Join-Path $InstallPath $Config.VMDiskName
    
    # Start-only mode
    if ($StartOnly) {
        if (-not (Test-Path $diskPath)) {
            Write-Log "VM disk not found. Run without -StartOnly first." -Level ERROR
            exit 1
        }
        Start-VMKiosk -DiskPath $diskPath
        return
    }
    
    try {
        # Install QEMU
        if (-not $SkipQEMUInstall) {
            Install-QEMU
        }
        
        $env:Path = "$($Config.QEMUInstallPath);$env:Path"
        
        # Create VM
        if (-not $SkipVMCreate) {
            $isoPath = Get-DebianISO
            $preseedPath = New-PreseedConfig
            $diskPath = New-VMDisk
            
            # Create shortcuts
            New-AllShortcuts -InstallPath $InstallPath
            
            # Start installation
            Start-VMInstall -ISOPath $isoPath -DiskPath $diskPath -PreseedPath $preseedPath
        }
        
        Write-LogSection "Setup Complete!"
        Write-Log "Installation finished successfully" -Level SUCCESS
        Write-Log "Log file: $script:LogFile" -Level INFO
        
        Write-Host ""
        Write-Host "  To start the psDoom kiosk:" -ForegroundColor White
        Write-Host "    - Use the desktop shortcut 'psDoom Kiosk'" -ForegroundColor Cyan
        Write-Host "    - Or run: .\psdoom-kiosk.ps1 -StartOnly" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Log file: $script:LogFile" -ForegroundColor DarkGray
        Write-Host ""
    }
    catch {
        Write-Log "Installation failed: $_" -Level ERROR
        Write-Log $_.ScriptStackTrace -Level DEBUG
        throw
    }
}

# Run
Main
