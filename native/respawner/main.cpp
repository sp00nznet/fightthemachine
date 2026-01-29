/*
 * Fight the Machine - Native Windows Process Respawner
 *
 * Monitors processes and respawns them when killed by the game.
 * This is the Windows-native equivalent of process-respawner.py.
 *
 * Processes are classified into DOOM enemy tiers with corresponding
 * respawn delays to make the game more interesting.
 */

#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <map>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <atomic>

#pragma comment(lib, "psapi.lib")

/* Configuration */
const int CHECK_INTERVAL_MS = 1000;
const int SNAPSHOT_INTERVAL = 30;  /* Full snapshot every 30 checks */

/* DOOM enemy tiers with respawn delays (min, max) in seconds */
struct TierConfig {
    const char* name;
    int minDelay;
    int maxDelay;
};

static const TierConfig TIER_CONFIGS[] = {
    { "zombieman",  5, 10 },
    { "imp",        8, 15 },
    { "demon",     12, 20 },
    { "cacodemon", 15, 25 },
    { "baron",     20, 30 },
};

/* Process tier classifications */
static const char* TIER_ZOMBIEMAN[] = {
    "notepad.exe", "calc.exe", "mspaint.exe", "write.exe", "wordpad.exe", NULL
};
static const char* TIER_IMP[] = {
    "code.exe", "node.exe", "python.exe", "python3.exe", "powershell.exe", NULL
};
static const char* TIER_DEMON[] = {
    "chrome.exe", "firefox.exe", "msedge.exe", "discord.exe", "slack.exe", NULL
};
static const char* TIER_CACODEMON[] = {
    "dropbox.exe", "onedrive.exe", "steam.exe", NULL
};
static const char* TIER_BARON[] = {
    "outlook.exe", "excel.exe", "winword.exe", NULL
};

/* Blacklisted processes - never respawn these */
static const char* BLACKLIST[] = {
    "psdoom-ng.exe", "psdoom.exe", "fightthemachine.exe",
    "process-respawner.exe", "csrss.exe", "lsass.exe",
    "services.exe", "svchost.exe", "dwm.exe", "explorer.exe",
    "system", "system idle process", NULL
};

/* Global state */
struct ProcessRecord {
    DWORD pid;
    std::string name;
    std::string cmdLine;
    int tier;
};

static std::map<DWORD, ProcessRecord> g_knownProcesses;
static std::mutex g_mutex;
static std::atomic<bool> g_running(true);

/* Utility functions */
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

static int is_in_list(const char* name, const char** list) {
    for (int i = 0; list[i] != NULL; i++) {
        if (str_iequals(name, list[i])) {
            return 1;
        }
    }
    return 0;
}

static int is_blacklisted(const std::string& name) {
    return is_in_list(name.c_str(), BLACKLIST);
}

static int get_tier(const std::string& name) {
    if (is_in_list(name.c_str(), TIER_ZOMBIEMAN)) return 0;
    if (is_in_list(name.c_str(), TIER_IMP)) return 1;
    if (is_in_list(name.c_str(), TIER_DEMON)) return 2;
    if (is_in_list(name.c_str(), TIER_CACODEMON)) return 3;
    if (is_in_list(name.c_str(), TIER_BARON)) return 4;
    return 1;  /* Default to imp tier */
}

static float get_respawn_delay(int tier) {
    if (tier < 0 || tier >= 5) tier = 1;
    int minDelay = TIER_CONFIGS[tier].minDelay;
    int maxDelay = TIER_CONFIGS[tier].maxDelay;
    return minDelay + (float)(rand() % (maxDelay - minDelay + 1));
}

static std::map<DWORD, ProcessRecord> get_running_processes() {
    std::map<DWORD, ProcessRecord> processes;

    HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnap == INVALID_HANDLE_VALUE) {
        return processes;
    }

    PROCESSENTRY32W pe32;
    pe32.dwSize = sizeof(pe32);

    if (Process32FirstW(hSnap, &pe32)) {
        do {
            ProcessRecord record;
            record.pid = pe32.th32ProcessID;

            /* Convert wide string to narrow */
            char name[MAX_PATH];
            WideCharToMultiByte(CP_UTF8, 0, pe32.szExeFile, -1, name, MAX_PATH, NULL, NULL);
            record.name = name;
            record.tier = get_tier(record.name);
            record.cmdLine = record.name;  /* Simplified - just use name */

            processes[record.pid] = record;

        } while (Process32NextW(hSnap, &pe32));
    }

    CloseHandle(hSnap);
    return processes;
}

static void respawn_process(const ProcessRecord& record) {
    float delay = get_respawn_delay(record.tier);

    printf("[%s] Process '%s' killed. Respawning in %.1f seconds...\n",
           TIER_CONFIGS[record.tier].name, record.name.c_str(), delay);

    std::thread([record, delay]() {
        Sleep((DWORD)(delay * 1000));

        if (!g_running) return;

        /* Try to respawn the process */
        STARTUPINFOA si = { sizeof(si) };
        PROCESS_INFORMATION pi = {0};

        si.dwFlags = STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_SHOWMINIMIZED;

        std::string cmd = record.cmdLine;

        if (CreateProcessA(NULL, (LPSTR)cmd.c_str(), NULL, NULL, FALSE,
                          CREATE_NEW_CONSOLE, NULL, NULL, &si, &pi)) {
            printf("[%s] Respawned '%s' (new PID %lu)\n",
                   TIER_CONFIGS[record.tier].name, record.name.c_str(), pi.dwProcessId);
            CloseHandle(pi.hThread);
            CloseHandle(pi.hProcess);
        } else {
            printf("[WARNING] Could not respawn '%s' (error %lu)\n",
                   record.name.c_str(), GetLastError());
        }
    }).detach();
}

static BOOL WINAPI console_handler(DWORD signal) {
    if (signal == CTRL_C_EVENT || signal == CTRL_BREAK_EVENT || signal == CTRL_CLOSE_EVENT) {
        printf("\nShutdown requested...\n");
        g_running = false;
        return TRUE;
    }
    return FALSE;
}

int main(int argc, char* argv[]) {
    printf("==================================================\n");
    printf("Fight the Machine - Process Respawner Daemon\n");
    printf("==================================================\n\n");

    /* Seed random number generator */
    srand((unsigned int)time(NULL));

    /* Set up console handler */
    SetConsoleCtrlHandler(console_handler, TRUE);

    printf("Monitoring processes for game kills...\n\n");

    /* Initial snapshot */
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        g_knownProcesses = get_running_processes();
    }
    printf("Initial snapshot: %zu processes\n\n", g_knownProcesses.size());

    int checkCount = 0;

    while (g_running) {
        Sleep(CHECK_INTERVAL_MS);
        checkCount++;

        auto currentProcesses = get_running_processes();

        std::vector<ProcessRecord> killedProcesses;

        {
            std::lock_guard<std::mutex> lock(g_mutex);

            /* Find killed processes */
            for (const auto& kv : g_knownProcesses) {
                if (currentProcesses.find(kv.first) == currentProcesses.end()) {
                    /* Process was killed */
                    if (!is_blacklisted(kv.second.name)) {
                        killedProcesses.push_back(kv.second);
                    }
                }
            }

            /* Update known processes */
            if (checkCount >= SNAPSHOT_INTERVAL) {
                g_knownProcesses = currentProcesses;
                checkCount = 0;
            } else {
                /* Add new processes */
                for (const auto& kv : currentProcesses) {
                    if (g_knownProcesses.find(kv.first) == g_knownProcesses.end()) {
                        g_knownProcesses[kv.first] = kv.second;
                    }
                }
                /* Remove dead processes */
                for (const auto& record : killedProcesses) {
                    g_knownProcesses.erase(record.pid);
                }
            }
        }

        /* Schedule respawns for killed processes */
        for (const auto& record : killedProcesses) {
            respawn_process(record);
        }
    }

    printf("Process Respawner Daemon stopped\n");
    return 0;
}
