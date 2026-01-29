/*
 * Fight the Machine - Native Windows Process Handling
 * Implementation using Windows Toolhelp32 API
 *
 * This file implements process discovery and termination for the
 * native Windows port of psDoom-ng.
 *
 * SECURITY NOTE: This code can terminate arbitrary Windows processes.
 * A blacklist of critical system processes is enforced to prevent
 * system instability.
 */

#include "pr_process_win32.h"
#include "process_blacklist.h"
#include <psapi.h>
#include <stdio.h>
#include <string.h>

#pragma comment(lib, "psapi.lib")

/* Global process list */
static ProcessList g_process_list = {0};
static int g_initialized = 0;
static int g_safe_mode = 0;

/* Process tier classifications */
static const char* TIER_ZOMBIEMAN_PROCS[] = {
    "notepad.exe", "calc.exe", "mspaint.exe", "write.exe",
    "wordpad.exe", "charmap.exe", "snippingtool.exe", NULL
};

static const char* TIER_IMP_PROCS[] = {
    "code.exe", "devenv.exe", "node.exe", "python.exe", "python3.exe",
    "ruby.exe", "perl.exe", "php.exe", "java.exe", "javaw.exe",
    "powershell.exe", "cmd.exe", "git.exe", "npm.exe", NULL
};

static const char* TIER_DEMON_PROCS[] = {
    "chrome.exe", "firefox.exe", "msedge.exe", "opera.exe", "brave.exe",
    "slack.exe", "discord.exe", "teams.exe", "zoom.exe", "spotify.exe",
    "vlc.exe", "wmplayer.exe", "itunes.exe", NULL
};

static const char* TIER_CACODEMON_PROCS[] = {
    "dropbox.exe", "onedrive.exe", "googledrivesync.exe",
    "steamservice.exe", "steam.exe", "epicgameslauncher.exe",
    "adobearm.exe", "jusched.exe", NULL
};

static const char* TIER_BARON_PROCS[] = {
    "outlook.exe", "excel.exe", "winword.exe", "powerpnt.exe",
    "thunderbird.exe", "filezilla.exe", "putty.exe", "winscp.exe",
    NULL
};

/*
 * Case-insensitive string comparison
 */
static int str_iequals(const char* a, const char* b) {
    while (*a && *b) {
        char ca = (*a >= 'A' && *a <= 'Z') ? *a + 32 : *a;
        char cb = (*b >= 'A' && *b <= 'Z') ? *b + 32 : *b;
        if (ca != cb) return 0;
        a++;
        b++;
    }
    return *a == *b;
}

/*
 * Check if a string is in a null-terminated array
 */
static int is_in_list(const char* name, const char** list) {
    for (int i = 0; list[i] != NULL; i++) {
        if (str_iequals(name, list[i])) {
            return 1;
        }
    }
    return 0;
}

int pr_init(void) {
    if (g_initialized) {
        return 0;
    }

    memset(&g_process_list, 0, sizeof(g_process_list));
    g_initialized = 1;

    /* Initial process scan */
    pr_refresh_process_list();

    return 0;
}

void pr_shutdown(void) {
    g_initialized = 0;
    memset(&g_process_list, 0, sizeof(g_process_list));
}

int pr_refresh_process_list(void) {
    if (!g_initialized) {
        return -1;
    }

    HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnap == INVALID_HANDLE_VALUE) {
        return -1;
    }

    g_process_list.count = 0;

    PROCESSENTRY32 pe32;
    pe32.dwSize = sizeof(PROCESSENTRY32);

    if (!Process32First(hSnap, &pe32)) {
        CloseHandle(hSnap);
        return -1;
    }

    do {
        if (g_process_list.count >= MAX_PROCESSES) {
            break;
        }

        ProcessInfo* info = &g_process_list.processes[g_process_list.count];

        info->pid = pe32.th32ProcessID;
        info->parent_pid = pe32.th32ParentProcessID;

        /* Copy process name (convert from wide char if necessary) */
#ifdef UNICODE
        WideCharToMultiByte(CP_UTF8, 0, pe32.szExeFile, -1,
                           info->name, MAX_PROC_NAME, NULL, NULL);
#else
        strncpy(info->name, pe32.szExeFile, MAX_PROC_NAME - 1);
        info->name[MAX_PROC_NAME - 1] = '\0';
#endif

        /* Determine tier and blacklist status */
        info->tier = pr_get_process_tier(info->name);
        info->is_blacklisted = pr_is_blacklisted(info->name);

        /* Get memory usage */
        info->memory_usage = 0;
        HANDLE hProc = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
                                   FALSE, info->pid);
        if (hProc) {
            PROCESS_MEMORY_COUNTERS pmc;
            if (GetProcessMemoryInfo(hProc, &pmc, sizeof(pmc))) {
                info->memory_usage = pmc.WorkingSetSize;
            }
            CloseHandle(hProc);
        }

        g_process_list.count++;

    } while (Process32Next(hSnap, &pe32));

    CloseHandle(hSnap);
    return g_process_list.count;
}

const ProcessList* pr_get_process_list(void) {
    return &g_process_list;
}

const ProcessInfo* pr_get_process_info(DWORD pid) {
    for (int i = 0; i < g_process_list.count; i++) {
        if (g_process_list.processes[i].pid == pid) {
            return &g_process_list.processes[i];
        }
    }
    return NULL;
}

int pr_kill_process(DWORD pid) {
    /* Never kill our own process */
    if (pid == GetCurrentProcessId()) {
        return -1;
    }

    /* Find the process info */
    const ProcessInfo* info = pr_get_process_info(pid);
    if (!info) {
        return -1;
    }

    /* Check if blacklisted */
    if (info->is_blacklisted) {
        fprintf(stderr, "pr_kill_process: Refusing to kill blacklisted process '%s' (PID %lu)\n",
                info->name, pid);
        return -1;
    }

    /* In safe mode, only kill if it's a decoy process we spawned */
    if (g_safe_mode) {
        /* Check if it's a known safe target */
        /* For now, only allow notepad.exe and calc.exe in safe mode */
        if (!str_iequals(info->name, "notepad.exe") &&
            !str_iequals(info->name, "calc.exe") &&
            !str_iequals(info->name, "mspaint.exe")) {
            fprintf(stderr, "pr_kill_process: Safe mode - refusing to kill '%s'\n",
                    info->name);
            return -1;
        }
    }

    /* Open the process with terminate rights */
    HANDLE hProc = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
    if (!hProc) {
        DWORD err = GetLastError();
        fprintf(stderr, "pr_kill_process: OpenProcess failed for '%s' (PID %lu), error %lu\n",
                info->name, pid, err);
        return -1;
    }

    /* Terminate the process */
    BOOL result = TerminateProcess(hProc, 1);
    CloseHandle(hProc);

    if (!result) {
        DWORD err = GetLastError();
        fprintf(stderr, "pr_kill_process: TerminateProcess failed for '%s' (PID %lu), error %lu\n",
                info->name, pid, err);
        return -1;
    }

    printf("pr_kill_process: Killed '%s' (PID %lu)\n", info->name, pid);
    return 0;
}

int pr_renice_process(DWORD pid) {
    /* Find the process info */
    const ProcessInfo* info = pr_get_process_info(pid);
    if (!info) {
        return -1;
    }

    /* Check if blacklisted */
    if (info->is_blacklisted) {
        return -1;
    }

    /* Open the process with set information rights */
    HANDLE hProc = OpenProcess(PROCESS_SET_INFORMATION, FALSE, pid);
    if (!hProc) {
        return -1;
    }

    /* Set to idle priority */
    BOOL result = SetPriorityClass(hProc, IDLE_PRIORITY_CLASS);
    CloseHandle(hProc);

    if (!result) {
        return -1;
    }

    printf("pr_renice_process: Lowered priority of '%s' (PID %lu)\n",
           info->name, pid);
    return 0;
}

int pr_is_blacklisted(const char* process_name) {
    return is_process_blacklisted(process_name);
}

ProcessTier pr_get_process_tier(const char* process_name) {
    /* Check blacklist first */
    if (pr_is_blacklisted(process_name)) {
        return TIER_CYBERDEMON;
    }

    /* Check each tier */
    if (is_in_list(process_name, TIER_ZOMBIEMAN_PROCS)) {
        return TIER_ZOMBIEMAN;
    }
    if (is_in_list(process_name, TIER_IMP_PROCS)) {
        return TIER_IMP;
    }
    if (is_in_list(process_name, TIER_DEMON_PROCS)) {
        return TIER_DEMON;
    }
    if (is_in_list(process_name, TIER_CACODEMON_PROCS)) {
        return TIER_CACODEMON;
    }
    if (is_in_list(process_name, TIER_BARON_PROCS)) {
        return TIER_BARON;
    }

    /* Default to IMP tier for unknown processes */
    return TIER_IMP;
}

const char* pr_get_tier_name(ProcessTier tier) {
    switch (tier) {
        case TIER_ZOMBIEMAN:  return "Zombieman";
        case TIER_IMP:        return "Imp";
        case TIER_DEMON:      return "Demon";
        case TIER_CACODEMON:  return "Cacodemon";
        case TIER_BARON:      return "Baron of Hell";
        case TIER_CYBERDEMON: return "Cyberdemon (Protected)";
        default:              return "Unknown";
    }
}

void pr_set_safe_mode(int enabled) {
    g_safe_mode = enabled ? 1 : 0;
    if (g_safe_mode) {
        printf("pr_set_safe_mode: Safe mode ENABLED - only decoy processes can be killed\n");
    } else {
        printf("pr_set_safe_mode: Safe mode DISABLED - real processes can be killed\n");
    }
}

int pr_is_safe_mode(void) {
    return g_safe_mode;
}

DWORD pr_spawn_decoy_process(const char* name) {
    STARTUPINFOA si = { sizeof(si) };
    PROCESS_INFORMATION pi = {0};

    char cmdLine[MAX_PATH];

    /* Determine which process to spawn based on name */
    if (str_iequals(name, "notepad") || str_iequals(name, "notepad.exe")) {
        strcpy(cmdLine, "notepad.exe");
    } else if (str_iequals(name, "calc") || str_iequals(name, "calc.exe")) {
        strcpy(cmdLine, "calc.exe");
    } else if (str_iequals(name, "mspaint") || str_iequals(name, "mspaint.exe")) {
        strcpy(cmdLine, "mspaint.exe");
    } else {
        /* Default to notepad */
        strcpy(cmdLine, "notepad.exe");
    }

    /* Create the process minimized */
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_MINIMIZE;

    if (!CreateProcessA(NULL, cmdLine, NULL, NULL, FALSE,
                        CREATE_NEW_CONSOLE, NULL, NULL, &si, &pi)) {
        return 0;
    }

    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);

    printf("pr_spawn_decoy_process: Spawned '%s' (PID %lu)\n", cmdLine, pi.dwProcessId);
    return pi.dwProcessId;
}
