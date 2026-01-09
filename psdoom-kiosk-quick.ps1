<#
.SYNOPSIS
    psDoom Kiosk - Quick Installation (Debian Cloud Image)
    
.DESCRIPTION
    Downloads QEMU and a Debian cloud image, uses cloud-init to configure
    the psDoom kiosk automatically. Faster than full ISO install.
    
.NOTES
    Run as Administrator for best results.
#>

#Requires -Version 5.1

param(
    [string]$InstallPath = "$env:USERPROFILE\psdoom-kiosk",
    [int]$VMMemoryMB = 2048,
    [int]$VMCores = 2,
    [int]$VMDiskGB = 20,
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
    $script:LogFile = Join-Path $logDir "install-quick-$timestamp.log"
    
    $header = @"
================================================================================
psDoom Kiosk - Quick Installation Log
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
    QEMUUrl         = "https://qemu.weilnetz.de/w64/2024/qemu-w64-setup-20240217.exe"
    QEMUPath        = "C:\Program Files\qemu"
    
    DebianCloudUrl  = "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    DebianImageName = "debian-12-cloud.qcow2"
    
    VMDiskName      = "psdoom-disk.qcow2"
    CloudInitISO    = "cloud-init.iso"
}

# =============================================================================
# Helper Functions
# =============================================================================

function Get-FileWithProgress {
    param([string]$Url, [string]$Out)
    
    Write-Log "Downloading: $Url" -Level INFO
    Write-Log "Destination: $Out" -Level DEBUG
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        Start-BitsTransfer -Source $Url -Destination $Out -ErrorAction Stop
    } catch {
        Write-Log "BITS failed, using WebRequest: $_" -Level WARN
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $Out -UseBasicParsing
    }
    
    $stopwatch.Stop()
    
    if (Test-Path $Out) {
        $size = (Get-Item $Out).Length / 1MB
        Write-Log "Downloaded $([math]::Round($size, 2)) MB in $([math]::Round($stopwatch.Elapsed.TotalSeconds, 1))s" -Level SUCCESS
    }
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
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
    
    $diskPath = Join-Path $InstallPath $Config.VMDiskName
    $qemuPath = Join-Path $Config.QEMUPath "qemu-system-x86_64.exe"
    
    # Create batch launcher
    $batchPath = Join-Path $InstallPath "Start-psDoom.bat"
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
    
    # Desktop shortcut - main launcher
    New-DesktopShortcut -Name "psDoom Kiosk" `
        -TargetPath $batchPath `
        -WorkingDirectory $InstallPath `
        -Description "Launch psDoom Kiosk VM"
    
    # Start Menu shortcut
    New-StartMenuShortcut -Name "psDoom Kiosk" `
        -TargetPath $batchPath `
        -WorkingDirectory $InstallPath
    
    # Desktop shortcut - open folder
    New-DesktopShortcut -Name "psDoom Kiosk - Open Folder" `
        -TargetPath "explorer.exe" `
        -Arguments $InstallPath `
        -Description "Open psDoom Kiosk installation folder"
    
    # Desktop shortcut - view logs
    $logsPath = Join-Path $InstallPath "logs"
    New-DesktopShortcut -Name "psDoom Kiosk - View Logs" `
        -TargetPath "explorer.exe" `
        -Arguments $logsPath `
        -Description "Open psDoom Kiosk logs folder"
}

# =============================================================================
# Installation Functions
# =============================================================================

function Install-QEMU {
    Write-LogSection "Installing QEMU"
    
    $qemuExe = Join-Path $Config.QEMUPath "qemu-system-x86_64.exe"
    
    if (Test-Path $qemuExe) {
        Write-Log "QEMU already installed" -Level SUCCESS
        return
    }
    
    $installer = Join-Path $InstallPath "qemu-setup.exe"
    if (-not (Test-Path $installer)) {
        Get-FileWithProgress -Url $Config.QEMUUrl -Out $installer
    }
    
    Write-Log "Installing QEMU (silent)..." -Level INFO
    $process = Start-Process -FilePath $installer -ArgumentList "/S" -Wait -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-Log "QEMU installation failed with code: $($process.ExitCode)" -Level ERROR
        throw "QEMU installation failed"
    }
    
    Write-Log "QEMU installed successfully" -Level SUCCESS
}

function New-CloudInitConfig {
    Write-LogSection "Creating Cloud-Init Configuration"
    
    $ciDir = Join-Path $InstallPath "cloud-init-data"
    New-Item -ItemType Directory -Path $ciDir -Force | Out-Null
    
    # Meta-data
    $metaData = @"
instance-id: psdoom-kiosk
local-hostname: psdoom-kiosk
"@
    $metaData | Out-File -FilePath (Join-Path $ciDir "meta-data") -Encoding ascii -NoNewline
    Write-Log "Created meta-data" -Level DEBUG
    
    # User-data with psDoom setup
    # Using single-quoted here-string to prevent PowerShell from interpreting
    # backticks and $() in the embedded Python script
    $userData = @'
#cloud-config

users:
  - name: doom
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: psdoom

package_update: true

packages:
  - xfce4
  - lightdm
  - xorg
  - git
  - build-essential
  - libsdl1.2-dev
  - libsdl-mixer1.2-dev
  - libsdl-net1.2-dev
  - wget

write_files:
  - path: /etc/lightdm/lightdm.conf.d/50-autologin.conf
    content: |
      [Seat:*]
      autologin-user=doom
      autologin-user-timeout=0
      user-session=xfce

  - path: /usr/local/bin/process-respawner.py
    permissions: '0755'
    content: |
      #!/usr/bin/env python3
      """
      Process Respawner Daemon for psDoom
      
      Monitors running processes and respawns them when killed.
      Respawn delay is based on process "difficulty" (like DOOM enemies):
      
      - Zombieman (low priority, small): 5-10 seconds
      - Imp (user processes): 8-15 seconds  
      - Demon (system services): 12-20 seconds
      - Cacodemon (important daemons): 15-25 seconds
      - Baron of Hell (critical services): 20-30 seconds
      
      The harder the enemy, the longer it takes to respawn!
      """
      
      import subprocess
      import time
      import random
      import os
      import sys
      import signal
      import threading
      import logging
      from datetime import datetime
      from pathlib import Path
      
      # Logging setup
      LOG_FILE = "/var/log/process-respawner.log"
      logging.basicConfig(
          level=logging.INFO,
          format='%(asctime)s [%(levelname)s] %(message)s',
          handlers=[
              logging.FileHandler(LOG_FILE),
              logging.StreamHandler()
          ]
      )
      log = logging.getLogger("respawner")
      
      # Process classification based on DOOM enemy difficulty
      # Higher tier = harder enemy = longer respawn time
      
      PROCESS_TIERS = {
          # Tier 1: Zombieman - Trivial processes (5-10 sec)
          "zombieman": {
              "delay_range": (5, 10),
              "patterns": [
                  "cat", "sleep", "yes", "true", "false", "echo",
                  "head", "tail", "wc", "sort", "uniq", "cut",
                  "tee", "xargs", "watch"
              ]
          },
          
          # Tier 2: Imp - User applications (8-15 sec)
          "imp": {
              "delay_range": (8, 15),
              "patterns": [
                  "vim", "nano", "less", "more", "man", "info",
                  "top", "htop", "ps", "pstree", "free",
                  "df", "du", "find", "grep", "sed", "awk",
                  "python", "perl", "ruby", "node", "php"
              ]
          },
          
          # Tier 3: Demon - Desktop/session processes (12-20 sec)
          "demon": {
              "delay_range": (12, 20),
              "patterns": [
                  "xfce4", "xfwm", "xfdesktop", "xfce4-panel",
                  "thunar", "mousepad", "ristretto",
                  "pulseaudio", "pipewire", "dbus-daemon",
                  "gvfs", "tumbler", "at-spi", "ibus"
              ]
          },
          
          # Tier 4: Cacodemon - Important system daemons (15-25 sec)
          "cacodemon": {
              "delay_range": (15, 25),
              "patterns": [
                  "cron", "atd", "anacron", "rsyslog", "syslog",
                  "NetworkManager", "wpa_supplicant", "dhclient",
                  "avahi", "cups", "bluetooth", "polkit",
                  "udisks", "upower", "accounts-daemon"
              ]
          },
          
          # Tier 5: Baron of Hell - Critical services (20-30 sec)
          "baron": {
              "delay_range": (20, 30),
              "patterns": [
                  "systemd", "init", "dbus", "udev",
                  "lightdm", "gdm", "sddm", "Xorg", "X",
                  "ssh", "sshd", "login", "getty"
              ]
          }
      }
      
      # Processes to never respawn (would break things or are psDoom itself)
      BLACKLIST = [
          "psdoom", "doom", "process-respawner", "respawner",
          "cloud-init", "setup-psdoom", "bash", "sh", "dash",
          "sudo", "su", "passwd", "chown", "chmod",
          "apt", "dpkg", "apt-get", "aptitude",
          "systemctl", "journalctl", "mount", "umount",
          "kill", "pkill", "killall", "reboot", "shutdown", "halt"
      ]
      
      # Services that can be restarted via systemctl
      SYSTEMD_SERVICES = {
          "cron": "cron",
          "rsyslog": "rsyslog", 
          "syslog": "rsyslog",
          "NetworkManager": "NetworkManager",
          "wpa_supplicant": "wpa_supplicant",
          "avahi-daemon": "avahi-daemon",
          "cups": "cups",
          "bluetooth": "bluetooth",
          "polkitd": "polkit",
          "udisksd": "udisks2",
          "upowerd": "upower",
          "lightdm": "lightdm",
          "dbus-daemon": "dbus"
      }
      
      class ProcessMonitor:
          def __init__(self):
              self.tracked_processes = {}  # pid -> {name, cmdline, tier, start_time}
              self.respawn_queue = []  # [(respawn_time, process_info), ...]
              self.running = True
              self.lock = threading.Lock()
              
          def get_tier(self, process_name):
              """Classify process into DOOM enemy tier"""
              name_lower = process_name.lower()
              
              for tier_name, tier_info in PROCESS_TIERS.items():
                  for pattern in tier_info["patterns"]:
                      if pattern.lower() in name_lower:
                          return tier_name, tier_info["delay_range"]
              
              # Default: Imp tier for unknown processes
              return "imp", PROCESS_TIERS["imp"]["delay_range"]
          
          def is_blacklisted(self, process_name):
              """Check if process should never be respawned"""
              name_lower = process_name.lower()
              return any(bl.lower() in name_lower for bl in BLACKLIST)
          
          def get_running_processes(self):
              """Get dict of currently running processes"""
              processes = {}
              try:
                  result = subprocess.run(
                      ["ps", "-eo", "pid,comm,args", "--no-headers"],
                      capture_output=True, text=True, timeout=5
                  )
                  for line in result.stdout.strip().split('\n'):
                      if not line.strip():
                          continue
                      parts = line.split(None, 2)
                      if len(parts) >= 2:
                          pid = int(parts[0])
                          name = parts[1]
                          cmdline = parts[2] if len(parts) > 2 else name
                          processes[pid] = {"name": name, "cmdline": cmdline}
              except Exception as e:
                  log.error(f"Error getting processes: {e}")
              return processes
          
          def snapshot_processes(self):
              """Take a snapshot of current processes to track"""
              current = self.get_running_processes()
              
              with self.lock:
                  for pid, info in current.items():
                      if pid not in self.tracked_processes:
                          if not self.is_blacklisted(info["name"]):
                              tier, delay_range = self.get_tier(info["name"])
                              self.tracked_processes[pid] = {
                                  "name": info["name"],
                                  "cmdline": info["cmdline"],
                                  "tier": tier,
                                  "delay_range": delay_range,
                                  "start_time": time.time()
                              }
              
              log.info(f"Tracking {len(self.tracked_processes)} processes")
          
          def check_for_deaths(self):
              """Check if any tracked processes have died"""
              current = self.get_running_processes()
              current_pids = set(current.keys())
              
              with self.lock:
                  tracked_pids = set(self.tracked_processes.keys())
                  dead_pids = tracked_pids - current_pids
                  
                  for pid in dead_pids:
                      proc_info = self.tracked_processes.pop(pid)
                      
                      # Calculate respawn delay based on tier
                      min_delay, max_delay = proc_info["delay_range"]
                      delay = random.uniform(min_delay, max_delay)
                      respawn_time = time.time() + delay
                      
                      log.warning(
                          f"KILLED: {proc_info['name']} (PID {pid}) "
                          f"[{proc_info['tier'].upper()}] - "
                          f"Respawning in {delay:.1f}s"
                      )
                      
                      self.respawn_queue.append((respawn_time, proc_info))
          
          def process_respawn_queue(self):
              """Respawn processes whose time has come"""
              now = time.time()
              
              with self.lock:
                  still_waiting = []
                  
                  for respawn_time, proc_info in self.respawn_queue:
                      if now >= respawn_time:
                          self.respawn_process(proc_info)
                      else:
                          still_waiting.append((respawn_time, proc_info))
                  
                  self.respawn_queue = still_waiting
          
          def respawn_process(self, proc_info):
              """Attempt to respawn a killed process"""
              name = proc_info["name"]
              cmdline = proc_info["cmdline"]
              tier = proc_info["tier"]
              
              log.info(f"RESPAWNING: {name} [{tier.upper()}]")
              
              try:
                  # Method 1: Try systemctl for known services
                  if name in SYSTEMD_SERVICES:
                      service = SYSTEMD_SERVICES[name]
                      subprocess.run(
                          ["systemctl", "start", service],
                          capture_output=True, timeout=10
                      )
                      log.info(f"Restarted service: {service}")
                      return
                  
                  # Method 2: Try to run the command directly
                  # For safety, only respawn if it looks like a simple command
                  if cmdline and not any(c in cmdline for c in [';', '|', '&', '`', '$(']):
                      # Run detached
                      subprocess.Popen(
                          cmdline.split(),
                          stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL,
                          start_new_session=True
                      )
                      log.info(f"Respawned: {cmdline}")
                      return
                  
                  # Method 3: Just try running by name
                  subprocess.Popen(
                      [name],
                      stdout=subprocess.DEVNULL,
                      stderr=subprocess.DEVNULL,
                      start_new_session=True
                  )
                  log.info(f"Respawned by name: {name}")
                  
              except Exception as e:
                  log.error(f"Failed to respawn {name}: {e}")
          
          def run(self):
              """Main monitoring loop"""
              log.info("=" * 50)
              log.info("Process Respawner Daemon Starting")
              log.info("The demons will keep coming back...")
              log.info("=" * 50)
              
              # Initial snapshot
              time.sleep(5)  # Wait for system to stabilize
              self.snapshot_processes()
              
              while self.running:
                  try:
                      # Check for dead processes
                      self.check_for_deaths()
                      
                      # Process respawn queue
                      self.process_respawn_queue()
                      
                      # Periodically refresh tracked processes
                      if random.random() < 0.1:  # ~10% chance each cycle
                          self.snapshot_processes()
                      
                      time.sleep(1)
                      
                  except Exception as e:
                      log.error(f"Monitor error: {e}")
                      time.sleep(5)
              
              log.info("Process Respawner Daemon Stopped")
          
          def stop(self):
              self.running = False
      
      def signal_handler(signum, frame):
          log.info(f"Received signal {signum}, shutting down...")
          monitor.stop()
          sys.exit(0)
      
      if __name__ == "__main__":
          # Handle signals gracefully
          signal.signal(signal.SIGTERM, signal_handler)
          signal.signal(signal.SIGINT, signal_handler)
          
          monitor = ProcessMonitor()
          monitor.run()

  - path: /etc/systemd/system/process-respawner.service
    content: |
      [Unit]
      Description=psDoom Process Respawner Daemon
      After=multi-user.target
      
      [Service]
      Type=simple
      ExecStart=/usr/bin/python3 /usr/local/bin/process-respawner.py
      Restart=always
      RestartSec=5
      StandardOutput=journal
      StandardError=journal
      
      [Install]
      WantedBy=multi-user.target

  - path: /home/doom/setup-psdoom.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -e
      exec > /home/doom/setup.log 2>&1
      echo "=== psDoom Setup Started ==="
      date
      
      cd /home/doom
      echo "Cloning psDoom..."
      git clone https://github.com/sp00nznet/psdoom-src.git build
      
      cd build/trunk
      echo "Configuring..."
      ./configure
      
      echo "Building..."
      make
      
      echo "Installing..."
      mkdir -p /home/doom/psdoom
      cp src/psdoom /home/doom/psdoom/
      
      cd /home/doom/psdoom
      echo "Downloading WAD..."
      wget -q https://archive.org/download/DoomsharewareDOOM1.WAD/DOOM1.WAD -O doom1.wad || \
      wget -q https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad -O doom1.wad || true
      
      echo "Cleaning up..."
      rm -rf /home/doom/build
      
      echo "Creating autostart..."
      mkdir -p /home/doom/.config/autostart
      cat > /home/doom/.config/autostart/psdoom.desktop << 'EOF'
      [Desktop Entry]
      Type=Application
      Name=psDoom
      Exec=/home/doom/start-psdoom.sh
      Hidden=false
      X-GNOME-Autostart-enabled=true
      EOF
      
      cat > /home/doom/start-psdoom.sh << 'EOF'
      #!/bin/bash
      sleep 3
      xset s off -dpms
      cd /home/doom/psdoom
      exec ./psdoom -fullscreen
      EOF
      chmod +x /home/doom/start-psdoom.sh
      
      chown -R doom:doom /home/doom
      
      echo "=== psDoom Setup Complete ==="
      date

runcmd:
  - systemctl enable lightdm
  - systemctl set-default graphical.target
  - systemctl daemon-reload
  - systemctl enable process-respawner.service
  - su - doom -c '/home/doom/setup-psdoom.sh'
  - systemctl start process-respawner.service
  - echo "Setup complete, rebooting..." >> /var/log/cloud-init-psdoom.log
  - reboot
'@
    $userData | Out-File -FilePath (Join-Path $ciDir "user-data") -Encoding ascii -NoNewline
    Write-Log "Created user-data" -Level DEBUG
    
    Write-Log "Cloud-init configuration created" -Level SUCCESS
    
    return $ciDir
}

function New-CloudInitISO {
    param([string]$CloudInitDir)
    
    Write-LogSection "Creating Cloud-Init ISO"
    
    $isoPath = Join-Path $InstallPath $Config.CloudInitISO
    
    # Try multiple methods to create ISO
    
    # Method 1: mkisofs from QEMU directory
    $mkisofs = Join-Path $Config.QEMUPath "mkisofs.exe"
    if (Test-Path $mkisofs) {
        Write-Log "Using mkisofs from QEMU" -Level DEBUG
        & $mkisofs -output $isoPath -volid cidata -joliet -rock $CloudInitDir 2>&1 | ForEach-Object { Write-Log $_ -Level DEBUG }
        if (Test-Path $isoPath) {
            Write-Log "Created cloud-init ISO: $isoPath" -Level SUCCESS
            return $isoPath
        }
    }
    
    # Method 2: oscdimg (Windows ADK)
    $oscdimg = Get-Command oscdimg -ErrorAction SilentlyContinue
    if ($oscdimg) {
        Write-Log "Using oscdimg" -Level DEBUG
        & oscdimg -j1 -o -lCIDATA $CloudInitDir $isoPath 2>&1 | ForEach-Object { Write-Log $_ -Level DEBUG }
        if (Test-Path $isoPath) {
            Write-Log "Created cloud-init ISO: $isoPath" -Level SUCCESS
            return $isoPath
        }
    }
    
    # Method 3: PowerShell ISO creation (basic)
    Write-Log "No ISO tool found - will pass cloud-init via QEMU args" -Level WARN
    return $null
}

function New-VMDisk {
    Write-LogSection "Creating VM Disk"
    
    $basePath = Join-Path $InstallPath $Config.DebianImageName
    $diskPath = Join-Path $InstallPath $Config.VMDiskName
    
    # Download base image if needed
    if (-not (Test-Path $basePath)) {
        Get-FileWithProgress -Url $Config.DebianCloudUrl -Out $basePath
    } else {
        Write-Log "Debian cloud image already downloaded" -Level SUCCESS
    }
    
    # Create disk from base
    if (Test-Path $diskPath) {
        Write-Log "Removing existing disk..." -Level WARN
        Remove-Item $diskPath -Force
    }
    
    Write-Log "Creating VM disk from cloud image..." -Level INFO
    Copy-Item $basePath $diskPath
    
    $qemuImg = Join-Path $Config.QEMUPath "qemu-img.exe"
    Write-Log "Resizing disk to ${VMDiskGB}GB..." -Level INFO
    $result = & $qemuImg resize $diskPath "${VMDiskGB}G" 2>&1
    Write-Log "qemu-img: $result" -Level DEBUG
    
    Write-Log "VM disk created: $diskPath" -Level SUCCESS
    return $diskPath
}

function Start-Kiosk {
    param(
        [string]$DiskPath,
        [string]$CloudInitISO = $null
    )
    
    $qemu = Join-Path $Config.QEMUPath "qemu-system-x86_64.exe"
    
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
    )
    
    if ($CloudInitISO -and (Test-Path $CloudInitISO)) {
        $qemuArgs += @("-cdrom", $CloudInitISO)
        Write-Log "Attaching cloud-init ISO" -Level DEBUG
    }
    
    Write-Log "Starting QEMU..." -Level INFO
    Write-Log "Args: $($qemuArgs -join ' ')" -Level DEBUG
    
    Start-Process -FilePath $qemu -ArgumentList $qemuArgs
    
    Write-Log "QEMU started" -Level SUCCESS
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
    Write-Host "              KIOSK (Quick Install)     " -ForegroundColor DarkRed
    Write-Host ""
    
    # Create directory
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    
    # Initialize logging
    Initialize-Logging -BasePath $InstallPath
    
    Write-Log "psDoom Kiosk Quick Installation starting..." -Level INFO
    Write-Log "Install path: $InstallPath" -Level INFO
    Write-Log "VM specs: ${VMMemoryMB}MB RAM, $VMCores cores, ${VMDiskGB}GB disk" -Level INFO
    
    if (-not (Test-Administrator)) {
        Write-Log "Not running as Administrator" -Level WARN
    } else {
        Write-Log "Running as Administrator" -Level SUCCESS
    }
    
    $diskPath = Join-Path $InstallPath $Config.VMDiskName
    
    if ($StartOnly) {
        if (-not (Test-Path $diskPath)) {
            Write-Log "No VM found. Run without -StartOnly first." -Level ERROR
            exit 1
        }
        Start-Kiosk -DiskPath $diskPath
        exit 0
    }
    
    try {
        # Install QEMU
        Install-QEMU
        $env:Path = "$($Config.QEMUPath);$env:Path"
        
        # Create cloud-init config
        $cloudInitDir = New-CloudInitConfig
        $cloudInitISO = New-CloudInitISO -CloudInitDir $cloudInitDir
        
        # Create VM disk
        $diskPath = New-VMDisk
        
        # Create shortcuts
        New-AllShortcuts -InstallPath $InstallPath
        
        Write-LogSection "Starting VM"
        
        Write-Host ""
        Write-Host "  The VM will now boot and configure itself." -ForegroundColor Yellow
        Write-Host "  This takes about 10-15 minutes." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  What happens:" -ForegroundColor Gray
        Write-Host "    1. Debian boots with cloud-init"
        Write-Host "    2. Packages are installed"
        Write-Host "    3. psDoom is cloned and built"
        Write-Host "    4. Auto-login is configured"
        Write-Host "    5. VM reboots into psDoom"
        Write-Host ""
        Write-Host "  Controls:" -ForegroundColor Gray
        Write-Host "    Ctrl+Alt+G = Release mouse"
        Write-Host "    Ctrl+Alt+F = Toggle fullscreen"
        Write-Host ""
        
        Start-Kiosk -DiskPath $diskPath -CloudInitISO $cloudInitISO
        
        Write-LogSection "Setup Complete!"
        Write-Log "Installation finished successfully" -Level SUCCESS
        Write-Log "Log file: $script:LogFile" -Level INFO
        
        Write-Host ""
        Write-Host "  Shortcuts created on Desktop:" -ForegroundColor Green
        Write-Host "    - psDoom Kiosk (launch VM)"
        Write-Host "    - psDoom Kiosk - Open Folder"
        Write-Host "    - psDoom Kiosk - View Logs"
        Write-Host ""
        Write-Host "  Log file: $script:LogFile" -ForegroundColor DarkGray
        Write-Host ""
    }
    catch {
        Write-Log "Installation failed: $_" -Level ERROR
        Write-Log $_.ScriptStackTrace -Level DEBUG
        Write-Host ""
        Write-Host "  Installation failed! Check log file:" -ForegroundColor Red
        Write-Host "  $script:LogFile" -ForegroundColor Yellow
        Write-Host ""
        throw
    }
}

# Run
Main
