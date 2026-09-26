# Roadmap

## Next

- **GitHub Actions CI.** On every push and PR: build the native exe under MSYS2
  and run `patches/portable-psdoom-wad.py --self-check`. On a `v*` tag, run
  `package.ps1` and attach the ZIP to a GitHub Release.
- **First tagged release**, `v1.1.0`, once CI produces it.
- **Re-verify the Win32 + QEMU build.** It hasn't been run since the GitLab CI
  went away.

## Later

- **File → Open for an IWAD.** Today you drop the WAD beside the exe or pass
  `-iwad`. A picker only matters if people find that confusing.
- **Safe-mode list in the config file**, instead of compiled in.
- **More monster types.** Today there are only two: demon and shotgun guy.

## Out of scope

- Shipping retail `doom.wad` / `doom2.wad`. Bring your own.
- Protecting against every way to hurt a Windows box. The protected list covers
  what keeps the session alive. Safe mode is the real guard rail.
