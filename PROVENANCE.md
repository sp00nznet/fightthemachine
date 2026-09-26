# Provenance

Third-party and derived assets this project ships, in the repo or in the release.

| Asset | Where | Source | Licence | Modified |
|---|---|---|---|---|
| `wad/psdoom1.wad`, `wad/psdoom2.wad` | repo + release | [psDoom](http://psdoom.sourceforge.net/) 2000.05.03 data | GPL-2.0 | Yes: texture lumps stripped, and psdoom1 made shareware-safe by `patches/portable-psdoom-wad.py` ([docs/iwads.md](docs/iwads.md)) |
| `wad/xdoom.wad` | repo | psDoom 2000.05.03 binary release (`psdoom-bin/`). Not used by the native build | As distributed with psDoom | No |
| `doom1.wad` | release ZIP only, never committed | id Software, DOOM shareware v1.9 (md5 `f0cefca49926d00903cf57551d901abe`) | Shareware, freely distributable, owned by id Software | No |
| `native/windows/app.ico` | repo | Drawn from geometry by `native/windows/make_icon.py`, using asset-forge's `pipelines/ui_icons.py`. No model involved | Project's own | n/a |
| `docs/screenshots/*.png` | repo | Captured from the running game | n/a | n/a |
