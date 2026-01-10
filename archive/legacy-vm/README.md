# Legacy VM Scripts (Archived)

> **Note:** These legacy scripts use the original "psDoom Kiosk" naming convention.
> The project has been renamed to **Fight the Machine** - see the main Docker implementation.

These scripts are from the original QEMU-based VM approach and have been superseded by the Docker implementation.

## Files

| File | Description |
|------|-------------|
| `Install-psDoomKiosk.ps1` | Interactive menu-driven Windows installer |
| `psdoom-kiosk.ps1` | Full installation using Debian ISO + preseed |
| `psdoom-kiosk-quick.ps1` | Quick installation using Debian cloud image |
| `cloud-init.iso` | Pre-built cloud-init ISO for VM configuration |
| `cloud-init-seed/` | Cloud-init source files (user-data, meta-data) |

## Why Archived?

The Docker approach is simpler and more portable:
- No QEMU installation required
- No full VM overhead
- Works on any platform with Docker
- Browser-based access via HTML5

## Using These Scripts

If you still want to use the VM approach:

1. Copy these files to your working directory
2. Run on Windows with PowerShell:
   ```powershell
   .\Install-psDoomKiosk.ps1
   ```

Requirements:
- Windows 10/11 (64-bit)
- ~25GB free disk space
- Administrator access (recommended)
