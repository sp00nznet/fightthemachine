# IWADs and the psDoom level WADs

What it takes to run on any IWAD, shareware included, and the three things that
broke along the way.

## How loading works

`D_FindIWAD` takes `-iwad` if you pass it. Otherwise it scans the exe's folder
in the order `doom2.wad`, `plutonia.wad`, `tnt.wad`, `doom.wad`, `doom1.wad`, ...,
`freedoom2.wad`, `freedoom1.wad` (`psdoom-ng-src/trunk/src/d_iwad.c`). psDoom
then adds its own level on top:

| IWAD game mode | Level loaded | Monsters spawn in |
|---|---|---|
| shareware, registered, retail | `psdoom1.wad` (E1M1) | three 1024x1024 arena boxes |
| commercial, DOOM II | `psdoom2.wad` (MAP01) | same boxes |
| Plutonia / TNT | none | nowhere: `pr_check` bails on add-on packs |

Both level WADs must sit **beside the exe**. `D_FindWADByName` does not look in
subfolders.

## 1. Missing level WAD = silent access violation

`D_FindWADByName` returns NULL when the file isn't there, and upstream passes
that straight into `D_AddFile` → `W_AddFile`, which reads `filename[0]`. The
result was exit code `0xC0000005` on startup with nothing printed.

Fix: `patches/fix-null-wad-crash.sh` guards `D_AddFile`, the one function every
caller goes through. It also sets `ps_level_loaded` from the real result, so
monsters fall back to the E1M1 courtyard instead of spawning into void
coordinates.

## 2. psdoom1.wad clobbered the IWAD's textures

The original `psdoom1.wad` carried Doom's `TEXTURE1`/`TEXTURE2`/`PNAMES`. A PWAD's
lumps win, so against Freedoom it swapped in Doom's 288-texture list, and any
Freedoom map using one outside it died:

```
R_TextureNumForName: <name> not found
```

The level only uses stock texture names, so the lumps were dropped
(`patches/portable-psdoom-wad.py`).

## 3. Shareware skipped the arena

Upstream only adds `psdoom1.wad` for `registered` and `retail`. On `doom1.wad`
the game still runs, but monsters go into E1M1's hidden courtyard. On a
Windows box with ~280 processes, the log was mostly this:

```
   process 35804 [tail.exe] monster at 2280 -3440
      repositioned at 2260 -3460
      ...
      not spawned for now, try next time.
```

A `sed` in `build-windows.sh` adds `shareware` to that condition. The level
then needed four things shareware lacks, which `portable-psdoom-wad.py
--shareware` swaps out:

| Missing in doom1.wad | Replaced with |
|---|---|
| `ASHWALL` wall texture | `STONE2` |
| `FLAT19`, `FLAT5_8` flats | `FLAT20`, `FLAT5_5` |
| BFG (2006), plasma gun (2004) | box of rockets, box of bullets |
| cell pack (17) | box of shells |

All of the replacements exist in every Doom 1 IWAD, so one `psdoom1.wad` covers
shareware, registered, Ultimate and Freedoom Phase 1. After the change the
same machine logged 262 monsters spawned and 12 deferred.

## Checked against

On 2026-09-26 each of these loaded its psDoom level and spawned 266-274 process
monsters: shareware `doom1.wad` v1.9, Ultimate DOOM `DOOM.WAD` (Steam, md5
`c4fe9fd9...`), DOOM II `DOOM2.WAD` (Steam, md5 `25e1459c...`), and Freedoom
Phase 1 0.13.0. The PID/name labels were checked by screenshot on the three
Doom 1 IWADs, Freedoom included. Freedoom used to show no labels. Exactly why
wasn't pinned down, but that stopped once bugs 1 and 2 were fixed.

The shareware v1.9 `doom1.wad` has md5 `f0cefca49926d00903cf57551d901abe`.
`package.ps1` refuses anything else.

Re-running the converter is harmless. It reports `already portable`:

```
python patches/portable-psdoom-wad.py --self-check
python patches/portable-psdoom-wad.py --shareware wad/psdoom1.wad
python patches/portable-psdoom-wad.py wad/psdoom2.wad
```
