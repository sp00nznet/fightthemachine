# Roadmap

## Next

- **Re-verify the Win32 + QEMU build.** It hasn't been run since the GitLab CI
  went away, and it has no GitHub Actions job yet.
- **Self-host the shareware WAD fetch.** `package.ps1` downloads `doom1.wad`
  from a third-party GitHub mirror. The md5 pin stops a tampered file, but not
  the mirror disappearing.

## Later

- **File → Open for an IWAD.** Today you drop the WAD beside the exe or pass
  `-iwad`. A picker only matters if people find that confusing.
- **Safe-mode list in the config file**, instead of compiled in.
- **More monster types.** Today there are only two: demon and shotgun guy.

## Out of scope

- Shipping retail `doom.wad` / `doom2.wad`. Bring your own.
- Protecting against every way to hurt a Windows box. The protected list covers
  what keeps the session alive. Safe mode is the real guard rail.
