<#
.SYNOPSIS
    psDoom Kiosk - Interactive Installer
    
.DESCRIPTION
    Interactive menu-driven installer for psDoom Kiosk VM.
    Choose between full ISO install or quick cloud image setup.
    
.NOTES
    Run as Administrator for best results.
    
.EXAMPLE
    .\Install-psDoomKiosk.ps1
#>

#Requires -Version 5.1

param(
    [switch]$NonInteractive,
    [ValidateSet("Full", "Quick")]
    [string]$Method,
    [string]$InstallPath,
    [int]$Memory,
    [int]$Cores,
    [int]$DiskSize
)

$ErrorActionPreference = "Stop"
$Host.UI.RawUI.WindowTitle = "psDoom Kiosk Installer"

# =============================================================================
# Logging
# =============================================================================

$script:LogFile = $null

function Initialize-Logging {
    param([string]$BasePath)
    
    $logDir = Join-Path $BasePath "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:LogFile = Join-Path $logDir "installer-$timestamp.log"
    
    $header = @"
================================================================================
psDoom Kiosk - Interactive Installer Log
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
}

# =============================================================================
# UI Helpers
# =============================================================================

function Clear-HostSafe {
    try { Clear-Host } catch { }
}

function Write-Logo {
    $logo = @"

    ____  _____ ____   ___   ___  __  __ 
   |  _ \/ ____|  _ \ / _ \ / _ \|  \/  |
   | |_) \___ \| | | | | | | | | | |\/| |
   |  __/ ___) | |_| | |_| | |_| | |  | |
   |_|   |____/|____/ \___/ \___/|_|  |_|
                    K I O S K
"@
    Write-Host $logo -ForegroundColor Red
    Write-Host "    Kill processes. Not demons. In a VM." -ForegroundColor DarkGray
    Write-Host ""
}

function Write-Header {
    param([string]$Text)
    $line = "-" * 60
    Write-Host ""
    Write-Host "  $line" -ForegroundColor DarkCyan
    Write-Host "    $Text" -ForegroundColor Cyan
    Write-Host "  $line" -ForegroundColor DarkCyan
    Write-Host ""
    Write-Log $Text -Level INFO
}

function Write-MenuOption {
    param(
        [string]$Key,
        [string]$Text,
        [string]$Description = ""
    )
    Write-Host "    [" -NoNewline -ForegroundColor DarkGray
    Write-Host $Key -NoNewline -ForegroundColor Yellow
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    Write-Host $Text -ForegroundColor White
    if ($Description) {
        Write-Host "        $Description" -ForegroundColor DarkGray
    }
}

function Write-Status {
    param(
        [string]$Text,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    $colors = @{
        Info    = "Cyan"
        Success = "Green"
        Warning = "Yellow"
        Error   = "Red"
    }
    $symbols = @{
        Info    = "i"
        Success = "+"
        Warning = "!"
        Error   = "x"
    }
    $levels = @{
        Info    = "INFO"
        Success = "SUCCESS"
        Warning = "WARN"
        Error   = "ERROR"
    }
    
    Write-Host "  [$($symbols[$Type])] " -NoNewline -ForegroundColor $colors[$Type]
    Write-Host $Text
    Write-Log $Text -Level $levels[$Type]
}

function Read-MenuChoice {
    param(
        [string]$Prompt = "Select option",
        [string[]]$ValidChoices
    )
    Write-Host ""
    Write-Host "  $Prompt`: " -NoNewline -ForegroundColor Cyan
    $choice = Read-Host
    
    Write-Log "User selected: $choice" -Level DEBUG
    
    if ($ValidChoices -and $choice -notin $ValidChoices) {
        Write-Status "Invalid choice. Please try again." -Type Warning
        return $null
    }
    return $choice
}

function Read-InputWithDefault {
    param(
        [string]$Prompt,
        [string]$Default
    )
    Write-Host "  $Prompt " -NoNewline -ForegroundColor White
    Write-Host "[$Default]" -NoNewline -ForegroundColor DarkGray
    Write-Host ": " -NoNewline
    $userInput = Read-Host
    if ([string]::IsNullOrWhiteSpace($userInput)) {
        return $Default
    }
    Write-Log "User input for '$Prompt': $userInput" -Level DEBUG
    return $userInput
}

# =============================================================================
# System Checks
# =============================================================================

function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    $issues = @()
    
    # Check admin
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        Write-Status "Running as Administrator" -Type Success
    } else {
        Write-Status "Not running as Administrator (some features may fail)" -Type Warning
        $issues += "admin"
    }
    
    # Check internet
    try {
        $null = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction Stop
        Write-Status "Internet connection available" -Type Success
    } catch {
        Write-Status "No internet connection detected" -Type Error
        $issues += "internet"
    }
    
    # Check disk space
    $drive = (Get-Item $env:USERPROFILE).PSDrive
    $freeGB = [math]::Round($drive.Free / 1GB, 1)
    if ($freeGB -gt 25) {
        Write-Status "Disk space: ${freeGB}GB free" -Type Success
    } elseif ($freeGB -gt 15) {
        Write-Status "Disk space: ${freeGB}GB free (minimum recommended: 25GB)" -Type Warning
    } else {
        Write-Status "Disk space: ${freeGB}GB free (need at least 15GB)" -Type Error
        $issues += "disk"
    }
    
    # Check if QEMU already installed
    $qemuPath = "C:\Program Files\qemu\qemu-system-x86_64.exe"
    if (Test-Path $qemuPath) {
        Write-Status "QEMU already installed" -Type Success
    } else {
        Write-Status "QEMU not installed (will be downloaded)" -Type Info
    }
    
    # Check for existing installation
    $defaultPath = "$env:USERPROFILE\psdoom-kiosk"
    if (Test-Path "$defaultPath\psdoom-disk.qcow2") {
        Write-Status "Existing psDoom VM found at $defaultPath" -Type Info
    }
    
    return $issues
}

# =============================================================================
# Menu Screens
# =============================================================================

function Show-MainMenu {
    Clear-HostSafe
    Write-Logo
    Write-Header "Main Menu"

    Write-MenuOption "1" "New Installation" "Set up a fresh psDoom kiosk VM"
    Write-MenuOption "2" "Start Existing VM" "Launch an already-installed kiosk"
    Write-MenuOption "3" "Configuration" "View/change settings"
    Write-MenuOption "4" "View Logs" "Open logs folder"
    Write-MenuOption "5" "Monitor Console" "Watch VM console output in real-time"
    Write-MenuOption "6" "Uninstall" "Remove psDoom kiosk"
    Write-Host ""
    Write-MenuOption "Q" "Quit" ""

    return Read-MenuChoice -Prompt "Select option" -ValidChoices @("1", "2", "3", "4", "5", "6", "Q", "q")
}

function Show-InstallMethodMenu {
    Clear-HostSafe
    Write-Logo
    Write-Header "Choose Installation Method"
    
    Write-Host "  Two installation methods are available:`n" -ForegroundColor Gray
    
    Write-MenuOption "1" "Quick Install (Recommended)" ""
    Write-Host "        Uses Debian cloud image with cloud-init" -ForegroundColor DarkGray
    Write-Host "        * Faster download (~700MB)" -ForegroundColor DarkGray
    Write-Host "        * Automated configuration" -ForegroundColor DarkGray
    Write-Host "        * ~10-15 minutes total" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-MenuOption "2" "Full Install" ""
    Write-Host "        Uses Debian netinst ISO with preseed" -ForegroundColor DarkGray
    Write-Host "        * Larger download (~600MB ISO + packages)" -ForegroundColor DarkGray
    Write-Host "        * Full OS installation" -ForegroundColor DarkGray
    Write-Host "        * ~20-30 minutes total" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-MenuOption "B" "Back" ""
    
    return Read-MenuChoice -Prompt "Select method" -ValidChoices @("1", "2", "B", "b")
}

function Show-ConfigurationMenu {
    param([hashtable]$CurrentConfig)
    
    Clear-HostSafe
    Write-Logo
    Write-Header "VM Configuration"
    
    Write-Host "  Current Settings:" -ForegroundColor Gray
    Write-Host ""
    Write-Host "    Install Path:  " -NoNewline -ForegroundColor DarkGray
    Write-Host $CurrentConfig.InstallPath -ForegroundColor White
    Write-Host "    VM Memory:     " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($CurrentConfig.Memory) MB" -ForegroundColor White
    Write-Host "    VM CPU Cores:  " -NoNewline -ForegroundColor DarkGray
    Write-Host $CurrentConfig.Cores -ForegroundColor White
    Write-Host "    VM Disk Size:  " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($CurrentConfig.DiskSize) GB" -ForegroundColor White
    Write-Host ""
    
    Write-MenuOption "1" "Change Install Path"
    Write-MenuOption "2" "Change Memory"
    Write-MenuOption "3" "Change CPU Cores"
    Write-MenuOption "4" "Change Disk Size"
    Write-MenuOption "R" "Reset to Defaults"
    Write-Host ""
    Write-MenuOption "B" "Back"
    
    return Read-MenuChoice -Prompt "Select option" -ValidChoices @("1", "2", "3", "4", "R", "r", "B", "b")
}

function Edit-Configuration {
    param([hashtable]$Config)
    
    while ($true) {
        $choice = Show-ConfigurationMenu -CurrentConfig $Config
        
        switch ($choice) {
            "1" {
                $newPath = Read-InputWithDefault -Prompt "Install path" -Default $Config.InstallPath
                $Config.InstallPath = $newPath
                Write-Log "Config changed: InstallPath = $newPath" -Level INFO
            }
            "2" {
                $newMem = Read-InputWithDefault -Prompt "Memory (MB)" -Default $Config.Memory
                if ($newMem -match '^\d+$') { 
                    $Config.Memory = [int]$newMem 
                    Write-Log "Config changed: Memory = $newMem" -Level INFO
                }
            }
            "3" {
                $newCores = Read-InputWithDefault -Prompt "CPU Cores" -Default $Config.Cores
                if ($newCores -match '^\d+$') { 
                    $Config.Cores = [int]$newCores 
                    Write-Log "Config changed: Cores = $newCores" -Level INFO
                }
            }
            "4" {
                $newDisk = Read-InputWithDefault -Prompt "Disk Size (GB)" -Default $Config.DiskSize
                if ($newDisk -match '^\d+$') { 
                    $Config.DiskSize = [int]$newDisk 
                    Write-Log "Config changed: DiskSize = $newDisk" -Level INFO
                }
            }
            { $_ -in "R", "r" } {
                $Config.InstallPath = "$env:USERPROFILE\psdoom-kiosk"
                $Config.Memory = 2048
                $Config.Cores = 2
                $Config.DiskSize = 20
                Write-Status "Configuration reset to defaults" -Type Success
                Write-Log "Config reset to defaults" -Level INFO
                Start-Sleep -Seconds 1
            }
            { $_ -in "B", "b" } {
                return $Config
            }
        }
    }
}

function Start-ExistingVM {
    param([hashtable]$Config)
    
    Clear-HostSafe
    Write-Logo
    Write-Header "Start Existing VM"
    
    $diskPath = Join-Path $Config.InstallPath "psdoom-disk.qcow2"
    $qemuPath = "C:\Program Files\qemu\qemu-system-x86_64.exe"
    
    if (-not (Test-Path $diskPath)) {
        Write-Status "No VM found at: $diskPath" -Type Error
        Write-Host ""
        Write-Host "  Run a new installation first." -ForegroundColor Gray
        Write-Host ""
        Read-Host "  Press Enter to continue"
        return
    }
    
    if (-not (Test-Path $qemuPath)) {
        Write-Status "QEMU not installed" -Type Error
        Write-Host ""
        Read-Host "  Press Enter to continue"
        return
    }
    
    Write-Status "Starting psDoom kiosk..." -Type Info
    Write-Host ""
    Write-Host "  Controls:" -ForegroundColor Gray
    Write-Host "    Ctrl+Alt+G    Release mouse" -ForegroundColor DarkGray
    Write-Host "    Ctrl+Alt+F    Toggle fullscreen" -ForegroundColor DarkGray
    Write-Host ""

    # Detect hardware acceleration
    $accelArg = @()
    $whpxTest = & $qemuPath -accel help 2>&1 | Out-String
    if ($whpxTest -match "whpx") {
        $accelArg = @("-accel", "whpx,kernel-irqchip=off")
        Write-Status "Using WHPX hardware acceleration" -Type Success
    } elseif ($whpxTest -match "hax") {
        $accelArg = @("-accel", "hax")
        Write-Status "Using HAXM hardware acceleration" -Type Success
    } else {
        $accelArg = @("-accel", "tcg")
        Write-Status "Using software emulation (slower)" -Type Warning
    }

    # Console log for monitoring
    $serialLog = Join-Path $Config.InstallPath "logs\vm-console.log"
    $logDir = Split-Path $serialLog -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $qemuArgs = @(
        "-name", "psDoom-Kiosk"
    ) + $accelArg + @(
        "-m", "$($Config.Memory)M"
        "-smp", "cores=$($Config.Cores)"
        "-hda", $diskPath
        "-boot", "c"
        "-netdev", "user,id=net0"
        "-device", "virtio-net-pci,netdev=net0"
        "-vga", "virtio"
        "-display", "sdl"
        "-serial", "file:$serialLog"
        "-full-screen"
    )
    
    Write-Log "Starting VM: $qemuPath $($qemuArgs -join ' ')" -Level INFO
    Start-Process -FilePath $qemuPath -ArgumentList $qemuArgs
    
    Write-Status "VM launched!" -Type Success
    Start-Sleep -Seconds 2
}

function Start-NewInstallation {
    param(
        [hashtable]$Config,
        [ValidateSet("Quick", "Full")]
        [string]$Method
    )
    
    Clear-HostSafe
    Write-Logo
    Write-Header "Installing psDoom Kiosk ($Method Method)"
    
    Write-Log "Starting $Method installation" -Level INFO
    
    # Get the script directory
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) { $scriptDir = Get-Location }
    
    $scriptName = if ($Method -eq "Quick") { "psdoom-kiosk-quick.ps1" } else { "psdoom-kiosk.ps1" }
    $scriptPath = Join-Path $scriptDir $scriptName
    
    if (-not (Test-Path $scriptPath)) {
        Write-Status "Installation script not found: $scriptPath" -Type Error
        Write-Log "Script not found: $scriptPath" -Level ERROR
        Write-Host ""
        Read-Host "  Press Enter to continue"
        return
    }
    
    Write-Status "Launching $scriptName..." -Type Info
    Write-Host ""
    Write-Host "  This will:" -ForegroundColor Gray
    Write-Host "    1. Download and install QEMU (if needed)" -ForegroundColor DarkGray
    Write-Host "    2. Download Debian image" -ForegroundColor DarkGray
    Write-Host "    3. Create and configure the VM" -ForegroundColor DarkGray
    Write-Host "    4. Build psDoom from source" -ForegroundColor DarkGray
    Write-Host "    5. Configure auto-login and kiosk mode" -ForegroundColor DarkGray
    Write-Host "    6. Create desktop shortcuts" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Estimated time: " -NoNewline -ForegroundColor Gray
    if ($Method -eq "Quick") {
        Write-Host "10-15 minutes" -ForegroundColor Yellow
    } else {
        Write-Host "20-30 minutes" -ForegroundColor Yellow
    }
    Write-Host ""
    
    $confirm = Read-MenuChoice -Prompt "Continue? (Y/n)" -ValidChoices @("Y", "y", "N", "n", "")
    if ($confirm -in @("N", "n")) {
        Write-Log "User cancelled installation" -Level INFO
        return
    }
    
    Write-Host ""
    Write-Status "Starting installation..." -Type Info
    Write-Host ""

    Write-Log "Running installation script: $scriptPath" -Level DEBUG
    Write-Log "Parameters: InstallPath=$($Config.InstallPath), Memory=$($Config.Memory), Cores=$($Config.Cores), Disk=$($Config.DiskSize)" -Level DEBUG

    # Run the installation script directly in this session (not as separate process)
    # This ensures we see all output and catch any errors
    try {
        & $scriptPath `
            -InstallPath $Config.InstallPath `
            -VMMemoryMB $Config.Memory `
            -VMCores $Config.Cores `
            -VMDiskGB $Config.DiskSize

        $exitCode = $LASTEXITCODE
        if ($exitCode -and $exitCode -ne 0) {
            throw "Installation script exited with code: $exitCode"
        }

        Write-Host ""
        Write-Status "Installation completed successfully!" -Type Success
        Write-Log "Installation script completed successfully" -Level SUCCESS
    }
    catch {
        Write-Host ""
        Write-Status "Installation failed: $_" -Type Error
        Write-Log "Installation failed: $_" -Level ERROR
        Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG
        Write-Host ""
        Write-Host "  Check the logs folder for details:" -ForegroundColor Yellow
        Write-Host "  $($Config.InstallPath)\logs" -ForegroundColor Gray
    }

    Write-Host ""
    Read-Host "  Press Enter to continue"
}

function Open-LogsFolder {
    param([hashtable]$Config)

    $logsPath = Join-Path $Config.InstallPath "logs"

    if (-not (Test-Path $logsPath)) {
        New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
    }

    Write-Log "Opening logs folder: $logsPath" -Level INFO
    Start-Process explorer.exe -ArgumentList $logsPath
}

function Watch-ConsoleLog {
    param([hashtable]$Config)

    $consolePath = Join-Path $Config.InstallPath "logs\vm-console.log"

    Clear-HostSafe
    Write-Logo
    Write-Header "Monitor VM Console Log"

    if (-not (Test-Path $consolePath)) {
        Write-Status "Console log not found: $consolePath" -Type Error
        Write-Host ""
        Write-Host "  The console log is created when the VM starts." -ForegroundColor Gray
        Write-Host "  Make sure you've run an installation or started the VM." -ForegroundColor Gray
        Write-Host ""
        Read-Host "  Press Enter to continue"
        return
    }

    Write-Host "  Watching: " -NoNewline -ForegroundColor Gray
    Write-Host $consolePath -ForegroundColor Cyan
    Write-Host "  Refreshing every 2 seconds. Press " -NoNewline -ForegroundColor Gray
    Write-Host "Q" -NoNewline -ForegroundColor Yellow
    Write-Host " to quit." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  " + ("-" * 56) -ForegroundColor DarkGray
    Write-Host ""

    Write-Log "Starting console log monitor: $consolePath" -Level INFO

    $lastSize = 0
    $linesToShow = 25

    # Set up key detection
    $host.UI.RawUI.FlushInputBuffer()

    while ($true) {
        # Check for key press (non-blocking)
        if ($host.UI.RawUI.KeyAvailable) {
            $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.Character -eq 'q' -or $key.Character -eq 'Q' -or $key.VirtualKeyCode -eq 27) {
                Write-Log "User exited console monitor" -Level INFO
                break
            }
        }

        # Check if file exists and has content
        if (Test-Path $consolePath) {
            $currentSize = (Get-Item $consolePath).Length

            # Only refresh display when file changes or first run
            if ($currentSize -ne $lastSize -or $lastSize -eq 0) {
                $lastSize = $currentSize

                # Get last N lines of file
                $content = Get-Content $consolePath -Tail $linesToShow -ErrorAction SilentlyContinue

                # Move cursor up to overwrite previous content (save position first)
                $cursorPos = $host.UI.RawUI.CursorPosition

                # Clear the display area and show new content
                $displayStartLine = 10  # After header
                $host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, $displayStartLine)

                # Clear lines
                for ($i = 0; $i -lt ($linesToShow + 2); $i++) {
                    Write-Host (" " * 80)
                }

                # Reset cursor and write content
                $host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates(0, $displayStartLine)

                if ($content) {
                    foreach ($line in $content) {
                        # Truncate long lines
                        if ($line.Length -gt 76) {
                            $line = $line.Substring(0, 73) + "..."
                        }

                        # Color code based on content
                        if ($line -match "error|fail|fatal" ) {
                            Write-Host "  $line" -ForegroundColor Red
                        } elseif ($line -match "warn") {
                            Write-Host "  $line" -ForegroundColor Yellow
                        } elseif ($line -match "success|complete|done|started|running") {
                            Write-Host "  $line" -ForegroundColor Green
                        } elseif ($line -match "cloud-init|psdoom|respawn") {
                            Write-Host "  $line" -ForegroundColor Cyan
                        } else {
                            Write-Host "  $line" -ForegroundColor Gray
                        }
                    }
                } else {
                    Write-Host "  (waiting for output...)" -ForegroundColor DarkGray
                }

                # Show file size and timestamp
                Write-Host ""
                $timestamp = Get-Date -Format "HH:mm:ss"
                Write-Host "  [$timestamp] Size: $currentSize bytes" -ForegroundColor DarkGray -NoNewline
                Write-Host "  |  Press Q to quit" -ForegroundColor DarkGray
            }
        }

        # Wait before next check
        Start-Sleep -Milliseconds 500
    }

    Write-Host ""
}

function Start-Uninstall {
    param([hashtable]$Config)
    
    Clear-HostSafe
    Write-Logo
    Write-Header "Uninstall psDoom Kiosk"
    
    Write-Host "  This will remove:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    * VM disk and configuration" -ForegroundColor Gray
    Write-Host "    * Downloaded ISO/images" -ForegroundColor Gray
    Write-Host "    * Launcher scripts" -ForegroundColor Gray
    Write-Host "    * Desktop shortcuts" -ForegroundColor Gray
    Write-Host "    * Log files" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Location: $($Config.InstallPath)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  QEMU will NOT be uninstalled." -ForegroundColor DarkGray
    Write-Host ""
    
    $confirm = Read-MenuChoice -Prompt "Are you sure? (y/N)" -ValidChoices @("Y", "y", "N", "n", "")
    
    if ($confirm -notin @("Y", "y")) {
        Write-Status "Uninstall cancelled" -Type Info
        Start-Sleep -Seconds 1
        return
    }
    
    Write-Log "User confirmed uninstall" -Level INFO
    
    # Remove install directory
    if (Test-Path $Config.InstallPath) {
        Write-Status "Removing $($Config.InstallPath)..." -Type Info
        Remove-Item -Path $Config.InstallPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Status "Removed installation folder" -Type Success
        Write-Log "Removed: $($Config.InstallPath)" -Level INFO
    } else {
        Write-Status "Install directory not found" -Type Warning
    }
    
    # Remove desktop shortcuts
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $shortcuts = @(
        "psDoom Kiosk.lnk",
        "psDoom Kiosk - Open Folder.lnk",
        "psDoom Kiosk - View Logs.lnk"
    )
    
    foreach ($shortcut in $shortcuts) {
        $shortcutPath = Join-Path $desktopPath $shortcut
        if (Test-Path $shortcutPath) {
            Remove-Item $shortcutPath -Force
            Write-Status "Removed: $shortcut" -Type Success
            Write-Log "Removed shortcut: $shortcutPath" -Level INFO
        }
    }
    
    # Remove Start Menu shortcut
    $startMenuPath = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs\psDoom Kiosk.lnk"
    if (Test-Path $startMenuPath) {
        Remove-Item $startMenuPath -Force
        Write-Status "Removed Start Menu shortcut" -Type Success
        Write-Log "Removed: $startMenuPath" -Level INFO
    }
    
    Write-Host ""
    Write-Status "Uninstall complete!" -Type Success
    Read-Host "  Press Enter to continue"
}

# =============================================================================
# Main
# =============================================================================

function Main {
    # Default configuration
    $config = @{
        InstallPath = if ($InstallPath) { $InstallPath } else { "$env:USERPROFILE\psdoom-kiosk" }
        Memory      = if ($Memory) { $Memory } else { 2048 }
        Cores       = if ($Cores) { $Cores } else { 2 }
        DiskSize    = if ($DiskSize) { $DiskSize } else { 20 }
    }
    
    # Ensure install path exists for logging
    if (-not (Test-Path $config.InstallPath)) {
        New-Item -ItemType Directory -Path $config.InstallPath -Force | Out-Null
    }
    
    # Initialize logging
    Initialize-Logging -BasePath $config.InstallPath
    Write-Log "Interactive installer started" -Level INFO
    Write-Log "Config: $($config | ConvertTo-Json -Compress)" -Level DEBUG
    
    # Non-interactive mode
    if ($NonInteractive -and $Method) {
        Write-Log "Running in non-interactive mode: $Method" -Level INFO
        Start-NewInstallation -Config $config -Method $Method
        return
    }
    
    # Prerequisites check
    Clear-HostSafe
    Write-Logo
    $issues = Test-Prerequisites
    
    if ("internet" -in $issues) {
        Write-Host ""
        Write-Host "  Cannot proceed without internet connection." -ForegroundColor Red
        Write-Log "Aborting: No internet connection" -Level ERROR
        Write-Host ""
        Read-Host "  Press Enter to exit"
        return
    }
    
    if ("disk" -in $issues) {
        Write-Host ""
        $continue = Read-MenuChoice -Prompt "Continue anyway? (y/N)" -ValidChoices @("Y", "y", "N", "n", "")
        if ($continue -notin @("Y", "y")) {
            Write-Log "User chose not to continue due to disk space" -Level INFO
            return
        }
    }
    
    Start-Sleep -Seconds 1
    
    # Main menu loop
    while ($true) {
        $choice = Show-MainMenu
        
        switch ($choice) {
            "1" {
                $methodChoice = Show-InstallMethodMenu
                switch ($methodChoice) {
                    "1" { Start-NewInstallation -Config $config -Method "Quick" }
                    "2" { Start-NewInstallation -Config $config -Method "Full" }
                }
            }
            "2" {
                Start-ExistingVM -Config $config
            }
            "3" {
                $config = Edit-Configuration -Config $config
            }
            "4" {
                Open-LogsFolder -Config $config
            }
            "5" {
                Watch-ConsoleLog -Config $config
            }
            "6" {
                Start-Uninstall -Config $config
            }
            { $_ -in "Q", "q" } {
                Clear-HostSafe
                Write-Host ""
                Write-Host "  Thanks for using psDoom Kiosk!" -ForegroundColor Red
                Write-Host "  RIP AND TEAR!" -ForegroundColor DarkRed
                Write-Host ""
                Write-Log "User exited installer" -Level INFO
                return
            }
        }
    }
}

# Run
Main
