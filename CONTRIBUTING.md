# Contributing

1. Branch off `main`. PRs are squash-merged.
2. Build with `native/windows/build-windows.sh` and run the game once
   (`fightthemachine.exe -warp 1 1 -nopsact -window`). The log should show
   `adding psdoom1.wad` and monsters spawning.
3. If you touched the WAD converter, run `python patches/portable-psdoom-wad.py --self-check`.
4. Add a line under `Unreleased` in `CHANGELOG.md`. If behaviour changed, update
   the README or `docs/` in the same PR.

Never commit IWADs (`doom*.wad`), build output, or anything under `dist/`.

Anything that changes what can be killed (`pr_kill`, `WIN32_BLACKLIST`,
`WIN32_SAFE_LIST`) needs a sentence in the PR explaining why it's safe.
