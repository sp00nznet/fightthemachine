# Architecture

There are two builds, and they share one idea: psDoom-ng polls the process
table, turns each process into a monster, and kills the process when that
monster dies. They differ in *whose* processes those are.

## Native Windows

A single process. psDoom-ng runs as a Windows game, and
[native/windows/pr_process.c](../native/windows/pr_process.c) replaces
upstream's `ps`/`kill` shell-outs with Win32 calls.

```
 ┌─────────────────────────── fightthemachine.exe ───────────────────────────┐
 │                                                                            │
 │   Chocolate Doom engine  (SDL 1.2, psdoom-ng-src/, patched at build time)  │
 │        │                                        ▲                          │
 │        │ every few tics                         │ monster killed           │
 │        ▼                                        │                          │
 │   pr_check()                                pr_kill(pid)                   │
 │        │                                        │                          │
 │        ▼                                        ▼                          │
 │   CreateToolhelp32Snapshot           ┌── WIN32_BLACKLIST? ──▶ refuse       │
 │   Process32First/Next                ├── safe mode and not on              │
 │        │                             │   WIN32_SAFE_LIST?   ──▶ spare      │
 │        ▼                             ├── our own PID?       ──▶ refuse     │
 │   add_new_process()                  └── OpenProcess + TerminateProcess    │
 │     system/service ─▶ demon                                                │
 │     everything else ─▶ shotgun guy                                         │
 │     placed in psdoom1.wad's three 1024x1024 spawn boxes                    │
 │     (or E1M1's hidden courtyard if the level didn't load)                  │
 └────────────────────────────────────────────────────────────────────────────┘
        │ reads                                     │ kills
        ▼                                           ▼
   ┌─────────────┐                         ┌──────────────────┐
   │  IWAD       │  doom2 > doom > doom1   │  real Windows    │
   │  + psdoom   │  (auto-detected beside  │  processes, no   │
   │  level WAD  │   the exe, or -iwad)    │  respawn         │
   └─────────────┘                         └──────────────────┘
```

**Why the safety checks sit in `pr_kill`:** it is the only function that
calls `TerminateProcess`. Checking there means no path through the game can
kill a protected process, and no path can escape safe mode either.

**Why the source is patched rather than forked:** `build-windows.sh` clones
upstream psDoom-ng into `psdoom-ng-src/` (gitignored) and applies
`patches/*.sh` plus a `sed` or two. The repo carries only the diff, so
upstream fixes can still be picked up.

| Piece | Owns |
|---|---|
| `native/windows/CMakeLists.txt` | Which upstream sources are built. It swaps in our `pr_process.c` and sets the safe-mode default. |
| `native/windows/build-windows.sh` | Cloning and patching upstream, then configuring and building |
| `native/windows/package.ps1` | The release ZIP: exe, DLLs found by walking the import table, WADs, and the licence paperwork |
| `patches/` | Source patches and the WAD converter. See [iwads.md](iwads.md). |
| `wad/` | psDoom level data, already converted |

## Win32 + QEMU

Three processes across a VM boundary. Windows processes are never touched.

```
 WINDOWS HOST                                   LINUX GUEST (QEMU, qcow2)
 ┌──────────────────────────────┐               ┌────────────────────────────────┐
 │ fightthemachine.exe          │   launches    │ vm-init.sh                     │
 │ win32/main.cpp               │──────────────▶│   Xvfb :0                      │
 │   qemu_manager.cpp           │               │   x11vnc :5900                 │
 │     finds qemu-system-x86_64 │               │   websockify/noVNC :6080       │
 │     boots fightthemachine    │               │   process-respawner.py         │
 │       .qcow2                 │               │   psdoom-ng                    │
 │                              │  http :6080   │     PSDOOMKILLCMD='kill -9'    │
 │   WebView2 ◀─────────────────┼───────────────│                                │
 │     shows the noVNC page     │  (noVNC)      │ monster dies ─▶ kill -9 pid    │
 └──────────────────────────────┘               │ respawner  ─▶ starts it again  │
                                                └────────────────────────────────┘
```

| Piece | Owns |
|---|---|
| `win32/` | The host GUI: finding and launching QEMU, then embedding the noVNC view in WebView2 |
| `qemu/build-vm-image.sh` | Building the Alpine-based guest image with psDoom-ng compiled in |
| `qemu/vm-init.sh` | Guest boot: display, VNC bridge, respawner, game |
| `qemu/package-windows.ps1` | Bundling QEMU, the image and the host exe |

This build has not been exercised since the GitLab CI that produced it was
retired (see [ROADMAP.md](../ROADMAP.md)).
