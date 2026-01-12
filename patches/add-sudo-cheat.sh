#!/bin/bash
# Add "sudo" cheat code that combines IDDQD (god mode) and IDKFA (all weapons/keys/ammo)
# This script modifies the psdoom-ng source before compilation

ST_STUFF_C="$1"

if [ ! -f "$ST_STUFF_C" ]; then
    echo "Error: st_stuff.c not found at $ST_STUFF_C"
    exit 1
fi

echo "Adding sudo cheat code to $ST_STUFF_C"

# Add the cheat_sudo declaration after cheat_ammo declaration
sed -i '/^.*cheat_ammo.*=.*CHEAT.*"idkfa"/a \
// sudo cheat - combines IDDQD and IDKFA (god mode + all weapons\/keys\/ammo)\
static cheatseq_t cheat_sudo = CHEAT("sudo", 0);' "$ST_STUFF_C"

# Find the IDKFA handler block and add sudo handler after it
# The sudo handler combines god mode + all weapons/ammo/keys
# We look for the STSTR_KFAADDED message which ends the IDKFA block

sed -i '/plyr->message = DEH_String(STSTR_KFAADDED);/a \
    }\
    \
    // sudo cheat - combines god mode (IDDQD) + all weapons\/keys\/ammo (IDKFA)\
    else if (cht_CheckCheat(\&cheat_sudo, ev->data2))\
    {\
        // God mode (from IDDQD)\
        plyr->cheats |= CF_GODMODE;\
        if (plyr->mo)\
            plyr->mo->health = deh_god_mode_health;\
        plyr->health = deh_god_mode_health;\
        \
        // All weapons, ammo, and keys (from IDKFA)\
        plyr->armorpoints = deh_idkfa_armor;\
        plyr->armortype = deh_idkfa_armor_class;\
        \
        for (i=0;i<NUMWEAPONS;i++)\
            plyr->weaponowned[i] = true;\
        \
        for (i=0;i<NUMAMMO;i++)\
            plyr->ammo[i] = plyr->maxammo[i];\
        \
        for (i=0;i<NUMCARDS;i++)\
            plyr->cards[i] = true;\
        \
        plyr->message = DEH_String("SUDO: God mode + full arsenal activated!");' "$ST_STUFF_C"

echo "Sudo cheat code added successfully"
