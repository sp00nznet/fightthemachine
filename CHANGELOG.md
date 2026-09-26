# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions: [SemVer](https://semver.org/).

## [Unreleased]

### Added
- Runs on the shareware `doom1.wad`, with the psDoom arena loaded instead of E1M1's cramped courtyard.
- `native/windows/package.ps1` builds the release ZIP. It bundles the shareware `doom1.wad` (md5-pinned) and pulls in DLLs by walking the import table.
- `-unsafe` command-line flag. `SAFE_MODE=0` in `fightthemachine.cfg` passes it.
- Crosshair app icon, drawn from geometry by `native/windows/make_icon.py` (asset-forge `ui_icons`). It replaces an earlier SDXL-generated icon whose provenance was never recorded.
- `docs/architecture.md`, `docs/iwads.md`, `ROADMAP.md`, `PROVENANCE.md`, `CONTRIBUTING.md`.

### Changed
- `run.bat` no longer hard-codes an IWAD. The engine auto-detects `doom2.wad` / `doom.wad` / `doom1.wad` beside the exe.
- `psdoom1.wad` / `psdoom2.wad` no longer carry texture directories, and `psdoom1.wad` uses only shareware textures and weapons (`patches/portable-psdoom-wad.py`).
- README restructured: status, screenshot, getting started, real usage.

### Fixed
- Safe mode now works. The build flag and `SAFE_MODE` setting used to be ignored, so every process not on the protected list could be killed.
- Startup access violation when `psdoom1.wad` / `psdoom2.wad` was missing (`patches/fix-null-wad-crash.sh`).
- Freedoom maps crashing with `R_TextureNumForName: <name> not found`.

### Removed
- GitLab CI pipeline and GitLab mirror. The server is gone. `.gitlab-ci.yml` was also purged from git history, because it named an internal host.
- Freedoom as the bundled IWAD. It still works with `-iwad freedoom1.wad`.

## [1.0.0] - 2026-01-31

### Added
- Native Windows port of psDoom-ng. It kills real processes via `TerminateProcess` and never touches a protected-process list.
- Win32 + QEMU client that runs psDoom-ng in a Linux VM, with a process respawner.
- `sudo` cheat.
