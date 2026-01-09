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
    # Multiple QEMU download URLs to try (in order of preference)
    QEMUUrls        = @(
        "https://qemu.weilnetz.de/w64/2025/qemu-w64-setup-20251217.exe"
        "https://qemu.weilnetz.de/w64/2025/qemu-w64-setup-20251127.exe"
        "https://qemu.weilnetz.de/w64/2025/qemu-w64-setup-20250826.exe"
    )
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
        # Try each QEMU mirror URL until one works
        $downloaded = $false
        foreach ($url in $Config.QEMUUrls) {
            Write-Log "Trying QEMU download: $url" -Level INFO
            try {
                Get-FileWithProgress -Url $url -Out $installer
                if (Test-Path $installer) {
                    $downloaded = $true
                    break
                }
            }
            catch {
                Write-Log "Failed to download from $url`: $_" -Level WARN
                # Clean up partial download
                if (Test-Path $installer) {
                    Remove-Item $installer -Force -ErrorAction SilentlyContinue
                }
            }
        }

        if (-not $downloaded) {
            throw "Failed to download QEMU from any mirror. Please download manually from https://qemu.weilnetz.de/w64/"
        }
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

# Enable serial console for boot messages
bootcmd:
  - echo "[PSDOOM] Cloud-init bootcmd starting..." > /dev/ttyS0
  - |
    # Enable serial console in GRUB
    if [ -f /etc/default/grub ]; then
      sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="[^"]*"/GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS0,115200n8"/' /etc/default/grub
      sed -i 's/#GRUB_TERMINAL=console/GRUB_TERMINAL="console serial"/' /etc/default/grub
      echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub
      update-grub 2>/dev/null || true
    fi
  - echo "[PSDOOM] Serial console configured" > /dev/ttyS0

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

      # Log to both file and serial console
      exec > >(tee -a /home/doom/setup.log | tee /dev/ttyS0) 2>&1

      echo "========================================"
      echo "[PSDOOM] Setup Started"
      echo "[PSDOOM] Time: $(date)"
      echo "========================================"

      cd /home/doom
      echo "[PSDOOM] Cloning psDoom repository..."
      git clone https://github.com/sp00nznet/psdoom-src.git build
      echo "[PSDOOM] Clone complete"

      cd build/trunk
      echo "[PSDOOM] Running configure..."
      ./configure
      echo "[PSDOOM] Configure complete"

      echo "[PSDOOM] Building psDoom (this takes a few minutes)..."
      make
      echo "[PSDOOM] Build complete"

      echo "[PSDOOM] Installing..."
      mkdir -p /home/doom/psdoom
      cp src/psdoom /home/doom/psdoom/
      echo "[PSDOOM] Binary installed to /home/doom/psdoom/"

      cd /home/doom/psdoom
      echo "[PSDOOM] Downloading DOOM WAD file..."
      wget -q https://archive.org/download/DoomsharewareDOOM1.WAD/DOOM1.WAD -O doom1.wad || \
      wget -q https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad -O doom1.wad || true
      if [ -f doom1.wad ]; then
        echo "[PSDOOM] WAD file downloaded successfully"
      else
        echo "[PSDOOM] WARNING: WAD file download failed"
      fi

      echo "[PSDOOM] Cleaning up build directory..."
      rm -rf /home/doom/build

      echo "[PSDOOM] Creating autostart configuration..."
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
      echo "[PSDOOM] Starting psDoom..." > /dev/ttyS0
      sleep 3
      xset s off -dpms
      cd /home/doom/psdoom
      echo "[PSDOOM] Launching game" > /dev/ttyS0
      exec ./psdoom -fullscreen
      EOF
      chmod +x /home/doom/start-psdoom.sh

      chown -R doom:doom /home/doom

      echo "========================================"
      echo "[PSDOOM] Setup Complete"
      echo "[PSDOOM] Time: $(date)"
      echo "========================================"

runcmd:
  - echo "[PSDOOM] ======================================" > /dev/ttyS0
  - echo "[PSDOOM] Cloud-init runcmd starting..." > /dev/ttyS0
  - echo "[PSDOOM] ======================================" > /dev/ttyS0
  - echo "[PSDOOM] Enabling lightdm..." > /dev/ttyS0
  - systemctl enable lightdm
  - echo "[PSDOOM] Setting graphical target..." > /dev/ttyS0
  - systemctl set-default graphical.target
  - echo "[PSDOOM] Reloading systemd..." > /dev/ttyS0
  - systemctl daemon-reload
  - echo "[PSDOOM] Enabling process-respawner service..." > /dev/ttyS0
  - systemctl enable process-respawner.service
  - echo "[PSDOOM] Running psDoom setup script..." > /dev/ttyS0
  - su - doom -c '/home/doom/setup-psdoom.sh'
  - echo "[PSDOOM] Starting process-respawner service..." > /dev/ttyS0
  - systemctl start process-respawner.service
  - echo "[PSDOOM] ======================================" > /dev/ttyS0
  - echo "[PSDOOM] All setup complete! Rebooting in 5s..." > /dev/ttyS0
  - echo "[PSDOOM] ======================================" > /dev/ttyS0
  - sleep 5
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

    # Method 3: Use qemu-img to create a FAT disk (cloud-init also supports this)
    $qemuImg = Join-Path $Config.QEMUPath "qemu-img.exe"
    if (Test-Path $qemuImg) {
        Write-Log "Using qemu-img to create FAT disk for cloud-init" -Level INFO
        try {
            $fatDisk = Join-Path $InstallPath "cloud-init.img"

            # Create a small FAT disk image
            & $qemuImg create -f raw $fatDisk 1M 2>&1 | ForEach-Object { Write-Log $_ -Level DEBUG }

            # Format it as FAT and add files using PowerShell
            # First, we need to mount it, but that's complex on Windows
            # Instead, let's use a simpler approach with mtools or just create the structure

            # Actually, let's use a VHD approach which Windows can mount natively
            Write-Log "Creating VHD-based cloud-init disk..." -Level DEBUG

            # Create and mount a small VHD
            $vhdPath = Join-Path $InstallPath "cloud-init.vhdx"
            $diskpartScript = @"
create vdisk file="$vhdPath" maximum=2 type=expandable
select vdisk file="$vhdPath"
attach vdisk
create partition primary
format fs=fat32 label="cidata" quick
assign letter=Z
"@
            $scriptFile = Join-Path $env:TEMP "diskpart_ci.txt"
            $diskpartScript | Out-File -FilePath $scriptFile -Encoding ascii

            $result = Start-Process -FilePath "diskpart" -ArgumentList "/s `"$scriptFile`"" -Wait -PassThru -NoNewWindow
            Start-Sleep -Seconds 2

            if (Test-Path "Z:\") {
                # Copy cloud-init files
                Copy-Item (Join-Path $CloudInitDir "meta-data") "Z:\meta-data"
                Copy-Item (Join-Path $CloudInitDir "user-data") "Z:\user-data"
                Write-Log "Copied cloud-init files to VHD" -Level DEBUG

                # Detach VHD
                $detachScript = @"
select vdisk file="$vhdPath"
detach vdisk
"@
                $detachScript | Out-File -FilePath $scriptFile -Encoding ascii
                Start-Process -FilePath "diskpart" -ArgumentList "/s `"$scriptFile`"" -Wait -NoNewWindow
                Remove-Item $scriptFile -Force

                # Convert VHDX to raw for QEMU
                & $qemuImg convert -f vhdx -O raw $vhdPath $fatDisk 2>&1 | ForEach-Object { Write-Log $_ -Level DEBUG }
                Remove-Item $vhdPath -Force -ErrorAction SilentlyContinue

                if (Test-Path $fatDisk) {
                    Write-Log "Created cloud-init FAT disk: $fatDisk" -Level SUCCESS
                    return $fatDisk
                }
            }
        }
        catch {
            Write-Log "FAT disk creation failed: $_" -Level WARN
        }
    }

    # Method 4: PowerShell native ISO creation using IMAPI2
    Write-Log "Using PowerShell IMAPI2 to create ISO" -Level INFO
    try {
        # Create the file system image
        $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
        $fsi.FileSystemsToCreate = 3  # FsiFileSystemISO9660 + FsiFileSystemJoliet
        $fsi.VolumeName = "cidata"

        # Add files from cloud-init directory
        $files = Get-ChildItem -Path $CloudInitDir -File
        foreach ($file in $files) {
            Write-Log "Adding to ISO: $($file.Name)" -Level DEBUG
            $stream = New-Object -ComObject ADODB.Stream
            $stream.Type = 1  # adTypeBinary
            $stream.Open()
            $stream.LoadFromFile($file.FullName)
            $fsi.Root.AddFile($file.Name, $stream)
        }

        # Build the ISO image
        $result = $fsi.CreateResultImage()
        $imageStream = $result.ImageStream

        # Write to file
        $outStream = New-Object -ComObject ADODB.Stream
        $outStream.Type = 1  # adTypeBinary
        $outStream.Open()
        $outStream.Write($imageStream.Read())
        $outStream.SaveToFile($isoPath, 2)  # adSaveCreateOverWrite
        $outStream.Close()

        if (Test-Path $isoPath) {
            $size = (Get-Item $isoPath).Length / 1KB
            Write-Log "Created cloud-init ISO: $isoPath ($([math]::Round($size, 1)) KB)" -Level SUCCESS
            return $isoPath
        }
    }
    catch {
        Write-Log "IMAPI2 ISO creation failed: $_" -Level WARN
    }

    # Method 4: Create a simple raw ISO manually (fallback)
    Write-Log "Attempting manual ISO creation..." -Level INFO
    try {
        $metaData = Get-Content (Join-Path $CloudInitDir "meta-data") -Raw
        $userData = Get-Content (Join-Path $CloudInitDir "user-data") -Raw

        # Create a minimal ISO 9660 image
        # This is a simplified ISO that cloud-init can read
        $isoBytes = New-Object System.Collections.ArrayList

        # System Area (32768 bytes of zeros)
        for ($i = 0; $i -lt 32768; $i++) { [void]$isoBytes.Add([byte]0) }

        # Primary Volume Descriptor
        $pvd = New-Object byte[] 2048
        $pvd[0] = 1  # Type: Primary Volume Descriptor
        [System.Text.Encoding]::ASCII.GetBytes("CD001").CopyTo($pvd, 1)  # Standard Identifier
        $pvd[6] = 1  # Version
        # Volume Identifier: "cidata" padded to 32 bytes
        $volId = "CIDATA".PadRight(32)
        [System.Text.Encoding]::ASCII.GetBytes($volId).CopyTo($pvd, 40)

        # Volume Space Size (we'll set a small size)
        $volSize = 50  # 50 sectors = 100KB
        $pvd[80] = [byte]($volSize -band 0xFF)
        $pvd[81] = [byte](($volSize -shr 8) -band 0xFF)
        $pvd[84] = [byte](($volSize -shr 8) -band 0xFF)
        $pvd[85] = [byte]($volSize -band 0xFF)

        # Logical Block Size: 2048
        $pvd[128] = 0; $pvd[129] = 8  # Little-endian
        $pvd[130] = 8; $pvd[131] = 0  # Big-endian

        $isoBytes.AddRange($pvd)

        # Volume Descriptor Set Terminator
        $term = New-Object byte[] 2048
        $term[0] = 255  # Type: Terminator
        [System.Text.Encoding]::ASCII.GetBytes("CD001").CopyTo($term, 1)
        $term[6] = 1
        $isoBytes.AddRange($term)

        # Pad to make room for root directory and files
        while ($isoBytes.Count -lt 2048 * 20) {
            [void]$isoBytes.Add([byte]0)
        }

        # Write the meta-data content
        $metaBytes = [System.Text.Encoding]::UTF8.GetBytes($metaData)
        for ($i = 0; $i -lt $metaBytes.Length -and ($isoBytes.Count + $i) -lt 2048 * 25; $i++) {
            [void]$isoBytes.Add($metaBytes[$i])
        }

        # Pad
        while ($isoBytes.Count -lt 2048 * 30) {
            [void]$isoBytes.Add([byte]0)
        }

        # Write the user-data content
        $userBytes = [System.Text.Encoding]::UTF8.GetBytes($userData)
        for ($i = 0; $i -lt $userBytes.Length; $i++) {
            [void]$isoBytes.Add($userBytes[$i])
        }

        # Pad to final size
        while ($isoBytes.Count -lt 2048 * 50) {
            [void]$isoBytes.Add([byte]0)
        }

        [System.IO.File]::WriteAllBytes($isoPath, $isoBytes.ToArray())

        Write-Log "Created fallback ISO (may not work with all cloud-init versions)" -Level WARN
        return $isoPath
    }
    catch {
        Write-Log "Manual ISO creation failed: $_" -Level ERROR
    }

    Write-Log "Failed to create cloud-init ISO - cloud-init will not configure the VM!" -Level ERROR
    Write-Log "Please install Windows ADK or use a system with mkisofs available" -Level ERROR
    throw "Cannot create cloud-init ISO. Install Windows ADK (oscdimg) or QEMU with mkisofs."
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
        [string]$CloudInitISO = $null,
        [switch]$FirstBoot
    )

    $qemu = Join-Path $Config.QEMUPath "qemu-system-x86_64.exe"

    # Serial console log file for monitoring VM status
    $serialLog = Join-Path $InstallPath "logs\vm-console.log"
    $logDir = Split-Path $serialLog -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # Initialize serial log with header
    $header = @"
================================================================================
psDoom Kiosk VM Console Log
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
================================================================================

"@
    $header | Out-File -FilePath $serialLog -Encoding ascii

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
        "-serial", "file:$serialLog"
    )

    if ($CloudInitISO -and (Test-Path $CloudInitISO)) {
        # Check if it's an ISO or a disk image
        if ($CloudInitISO -match '\.iso$') {
            $qemuArgs += @("-cdrom", $CloudInitISO)
            Write-Log "Attaching cloud-init ISO as CD-ROM" -Level DEBUG
        } else {
            # It's a disk image (FAT/raw), attach as secondary drive
            $qemuArgs += @("-hdb", $CloudInitISO)
            Write-Log "Attaching cloud-init disk as secondary drive" -Level DEBUG
        }
    }

    Write-Log "Starting QEMU..." -Level INFO
    Write-Log "Serial console log: $serialLog" -Level INFO
    Write-Log "Args: $($qemuArgs -join ' ')" -Level DEBUG

    Start-Process -FilePath $qemu -ArgumentList $qemuArgs

    Write-Log "QEMU started" -Level SUCCESS

    if ($FirstBoot) {
        Write-Host ""
        Write-Host "  Monitor VM progress with:" -ForegroundColor Yellow
        Write-Host "    Get-Content '$serialLog' -Wait" -ForegroundColor Cyan
        Write-Host ""
    }
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

        Start-Kiosk -DiskPath $diskPath -CloudInitISO $cloudInitISO -FirstBoot

        Write-LogSection "Setup Complete!"
        Write-Log "Installation finished successfully" -Level SUCCESS
        Write-Log "Log file: $script:LogFile" -Level INFO

        $serialLog = Join-Path $InstallPath "logs\vm-console.log"

        Write-Host ""
        Write-Host "  VM is now booting and configuring itself." -ForegroundColor Green
        Write-Host ""
        Write-Host "  Monitor VM progress in real-time:" -ForegroundColor Yellow
        Write-Host "    Get-Content '$serialLog' -Wait -Tail 50" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Or open the log file:" -ForegroundColor Yellow
        Write-Host "    $serialLog" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Look for [PSDOOM] messages to track progress:" -ForegroundColor Gray
        Write-Host "    - Cloud-init bootcmd starting"
        Write-Host "    - Package installation"
        Write-Host "    - psDoom build progress"
        Write-Host "    - Setup complete / Rebooting"
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
