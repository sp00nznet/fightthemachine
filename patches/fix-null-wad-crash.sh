#!/bin/bash
# Fix a hard crash (access violation) when a WAD file can't be found.
#
# psdoom-ng looks up psdoom1.wad / psdoom2.wad with D_FindWADByName(), which
# returns NULL when the file isn't beside the executable, then passes that NULL
# straight to D_AddFile() -> W_AddFile(), which dereferences it at
# `filename[0] == '~'`. Result: 0xC0000005 on startup with no error message.
#
# Guard once in D_AddFile, the function every caller routes through, and only
# claim the psdoom level loaded if it actually did (ps_level_loaded drives
# monster spawn-box placement in pr_process.c).
#
# Usage: ./fix-null-wad-crash.sh path/to/src/doom/d_main.c

set -e

D_MAIN_C="$1"

if [ ! -f "$D_MAIN_C" ]; then
    echo "Error: d_main.c not found at $D_MAIN_C"
    exit 1
fi

if grep -q "filename == NULL" "$D_MAIN_C"; then
    echo "Null-WAD crash fix already applied to $D_MAIN_C"
    exit 0
fi

echo "Applying null-WAD crash fix to $D_MAIN_C"

# 1. Guard D_AddFile against a NULL filename.
sed -i '/^    printf(" adding %s/i\
    if (filename == NULL)\
    {\
        return false;\
    }\
' "$D_MAIN_C"

# 2. Only set ps_level_loaded when the psdoom level really loaded.
sed -i 's|D_AddFile(psdoom1wad);|ps_level_loaded = D_AddFile(psdoom1wad);|' "$D_MAIN_C"
sed -i 's|D_AddFile(psdoom2wad);|ps_level_loaded = D_AddFile(psdoom2wad);|' "$D_MAIN_C"
sed -i '/ps_level_loaded = D_AddFile(psdoom[12]wad);/{n;/ps_level_loaded = true;/d;}' "$D_MAIN_C"

echo "Null-WAD crash fix applied successfully"
