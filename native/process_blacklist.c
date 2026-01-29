/*
 * Fight the Machine - Process Blacklist Implementation
 * Critical system processes that must NEVER be terminated
 *
 * SECURITY CRITICAL: This file defines processes that are protected
 * from being killed by the game. Terminating these processes can
 * cause system crashes, data loss, or security vulnerabilities.
 */

#include "process_blacklist.h"
#include <string.h>
#include <ctype.h>

/*
 * Blacklisted processes with reasons
 * Format: { "process.exe", "reason" }
 */
typedef struct {
    const char* name;
    const char* reason;
} BlacklistEntry;

static const BlacklistEntry BLACKLIST[] = {
    /* Windows Core System */
    { "system",             "Windows kernel process" },
    { "system idle process", "Windows idle process" },
    { "smss.exe",           "Session Manager - critical for Windows" },
    { "csrss.exe",          "Client/Server Runtime - killing causes BSOD" },
    { "wininit.exe",        "Windows Initialization - system critical" },
    { "services.exe",       "Service Control Manager - manages all services" },
    { "lsass.exe",          "Local Security Authority - security critical" },
    { "lsaiso.exe",         "Credential Guard - security critical" },
    { "svchost.exe",        "Service Host - runs system services" },
    { "dwm.exe",            "Desktop Window Manager - manages display" },
    { "winlogon.exe",       "Windows Logon Process - handles user login" },
    { "fontdrvhost.exe",    "Font Driver Host - system display" },
    { "sihost.exe",         "Shell Infrastructure Host" },

    /* Windows Shell */
    { "explorer.exe",       "Windows Shell - killing loses taskbar/desktop" },
    { "searchui.exe",       "Windows Search UI" },
    { "searchapp.exe",      "Windows Search App" },
    { "startmenuexperiencehost.exe", "Start Menu" },
    { "shellexperiencehost.exe", "Windows Shell Experience" },
    { "runtimebroker.exe",  "Runtime Broker - manages app permissions" },

    /* Security Software */
    { "msmpeng.exe",        "Windows Defender Antimalware" },
    { "nissrv.exe",         "Windows Defender Network Inspection" },
    { "securityhealthservice.exe", "Windows Security Health" },
    { "mrt.exe",            "Malicious Software Removal Tool" },
    { "smartscreen.exe",    "Windows SmartScreen" },

    /* Hardware/Drivers */
    { "audiodg.exe",        "Windows Audio Device Graph - sound system" },
    { "taskhostw.exe",      "Task Host Window" },
    { "conhost.exe",        "Console Window Host" },
    { "spoolsv.exe",        "Print Spooler Service" },

    /* Critical Services */
    { "wuauserv.exe",       "Windows Update Service" },
    { "trustedinstaller.exe", "Windows Modules Installer" },
    { "tiworker.exe",       "Windows Update Worker" },
    { "msiexec.exe",        "Windows Installer" },

    /* Network */
    { "dnsmasq.exe",        "DNS/DHCP Server" },
    { "dnscache.exe",       "DNS Client Cache" },

    /* psDoom-ng itself */
    { "psdoom-ng.exe",      "This game - don't kill yourself!" },
    { "psdoom.exe",         "This game" },
    { "fightthemachine.exe", "This game's launcher" },
    { "process-respawner.exe", "Process respawner daemon" },

    /* End marker */
    { NULL, NULL }
};

/*
 * Case-insensitive string comparison
 */
static int str_iequals(const char* a, const char* b) {
    while (*a && *b) {
        char ca = tolower((unsigned char)*a);
        char cb = tolower((unsigned char)*b);
        if (ca != cb) return 0;
        a++;
        b++;
    }
    return *a == *b;
}

int is_process_blacklisted(const char* process_name) {
    if (!process_name) return 1;  /* NULL is blacklisted */

    for (int i = 0; BLACKLIST[i].name != NULL; i++) {
        if (str_iequals(process_name, BLACKLIST[i].name)) {
            return 1;
        }
    }
    return 0;
}

const char** get_blacklist(void) {
    /* Build a static array of just the names */
    static const char* names[sizeof(BLACKLIST)/sizeof(BLACKLIST[0])];
    static int initialized = 0;

    if (!initialized) {
        for (int i = 0; BLACKLIST[i].name != NULL; i++) {
            names[i] = BLACKLIST[i].name;
        }
        names[sizeof(BLACKLIST)/sizeof(BLACKLIST[0]) - 1] = NULL;
        initialized = 1;
    }

    return names;
}

const char* get_blacklist_reason(const char* process_name) {
    if (!process_name) return "Invalid process name";

    for (int i = 0; BLACKLIST[i].name != NULL; i++) {
        if (str_iequals(process_name, BLACKLIST[i].name)) {
            return BLACKLIST[i].reason;
        }
    }
    return NULL;
}
