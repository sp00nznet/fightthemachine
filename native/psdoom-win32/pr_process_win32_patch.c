/* pr_process.c - Windows Native Port
 * Original by Dennis Chao, modified by David Koppenhofer
 * Windows port for Fight the Machine project
 *
 * This file provides the Windows-specific implementation of process
 * enumeration and killing using the Windows Toolhelp32 API.
 *
 * The key changes from the Linux version:
 * 1. Process enumeration uses CreateToolhelp32Snapshot instead of popen("ps")
 * 2. Process killing uses TerminateProcess instead of system("kill -9")
 * 3. Process renicing uses SetPriorityClass instead of system("renice")
 */

/* =========================================================================
 * WINDOWS-SPECIFIC PROCESS ENUMERATION
 *
 * This code block replaces the Linux popen("ps ...") implementation.
 * Insert this into pr_process.c within the pr_check() function,
 * adding a new #elif defined(_WIN32) block.
 * ========================================================================= */

#if defined(_WIN32) || defined(_WIN64)

#include <windows.h>
#include <tlhelp32.h>
#include <psapi.h>
#include <sddl.h>

/* Windows blacklist - critical system processes that should never be killed */
static const char* WIN32_BLACKLIST[] = {
    /* Windows Core */
    "system", "smss.exe", "csrss.exe", "wininit.exe", "services.exe",
    "lsass.exe", "svchost.exe", "dwm.exe", "winlogon.exe",
    /* Windows Shell */
    "explorer.exe", "searchui.exe", "shellexperiencehost.exe",
    /* Security */
    "msmpeng.exe", "securityhealthservice.exe",
    /* This game */
    "psdoom-ng.exe", "psdoom.exe",
    NULL
};

/* Check if a process name is in the Windows blacklist */
static int win32_is_blacklisted(const char *name) {
    int i;
    for (i = 0; WIN32_BLACKLIST[i] != NULL; i++) {
        if (_stricmp(name, WIN32_BLACKLIST[i]) == 0) {
            return 1;
        }
    }
    return 0;
}

/* Get username for a process (simplified - returns "SYSTEM" or "User") */
static void win32_get_process_user(DWORD pid, char *username, size_t size) {
    HANDLE hProc;
    HANDLE hToken;
    PTOKEN_USER pUser = NULL;
    DWORD dwSize = 0;
    SID_NAME_USE SidType;
    char name[256];
    char domain[256];
    DWORD nameSize = sizeof(name);
    DWORD domainSize = sizeof(domain);

    strncpy(username, "SYSTEM", size);

    hProc = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
    if (!hProc) return;

    if (OpenProcessToken(hProc, TOKEN_QUERY, &hToken)) {
        GetTokenInformation(hToken, TokenUser, NULL, 0, &dwSize);
        if (dwSize > 0) {
            pUser = (PTOKEN_USER)malloc(dwSize);
            if (pUser && GetTokenInformation(hToken, TokenUser, pUser, dwSize, &dwSize)) {
                if (LookupAccountSidA(NULL, pUser->User.Sid, name, &nameSize,
                                      domain, &domainSize, &SidType)) {
                    strncpy(username, name, size);
                }
            }
            if (pUser) free(pUser);
        }
        CloseHandle(hToken);
    }
    CloseHandle(hProc);
}

/* Check if process is a service/daemon (no visible window) */
static int win32_is_daemon(DWORD pid) {
    HWND hwnd;
    DWORD windowPid;

    /* Simple heuristic: services typically don't have visible windows */
    hwnd = GetTopWindow(NULL);
    while (hwnd) {
        GetWindowThreadProcessId(hwnd, &windowPid);
        if (windowPid == pid && IsWindowVisible(hwnd)) {
            return 0; /* Has visible window, not a daemon */
        }
        hwnd = GetNextWindow(hwnd, GW_HWNDNEXT);
    }
    return 1; /* No visible window, treat as daemon */
}

/*
 * Windows implementation of pr_check()
 * This replaces the Linux popen("ps h a x u OT", "r") call
 */
static void win32_pr_check(void) {
    HANDLE hSnap;
    PROCESSENTRY32 pe32;
    char username[256];
    char *custompscmd;

    /* Check for custom command first (for compatibility) */
    if ((custompscmd = getenv("PSDOOMPSCMD")) != NULL) {
        FILE *f = _popen(custompscmd, "r");
        if (f) {
            char buf[256];
            char namebuf[256];
            int pid, demon;
            while (fgets(buf, 255, f)) {
                int read_fields = sscanf(buf, "%s %d %s %d",
                    username, &pid, namebuf, &demon);
                if (read_fields == 4) {
                    if ((psallusers || in_ps_userlist(psuser_list_head, username)) &&
                        !(in_ps_userlist(psnotuser_list_head, username))) {
                        add_to_pid_list(pid, namebuf, demon);
                    }
                }
            }
            _pclose(f);
            return;
        }
    }

    /* Create snapshot of all processes */
    hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnap == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "ERROR: pr_check could not create process snapshot\n");
        return;
    }

    pe32.dwSize = sizeof(PROCESSENTRY32);

    if (!Process32First(hSnap, &pe32)) {
        CloseHandle(hSnap);
        return;
    }

    do {
        DWORD pid = pe32.th32ProcessID;
        char *procname;
        int demon;

        /* Skip PID 0 (System Idle Process) and our own process */
        if (pid == 0 || pid == GetCurrentProcessId()) {
            continue;
        }

        /* Skip blacklisted system processes */
        if (win32_is_blacklisted(pe32.szExeFile)) {
            continue;
        }

        /* Get process name (without path) */
        procname = pe32.szExeFile;

        /* Get username for this process */
        win32_get_process_user(pid, username, sizeof(username));

        /* Determine if it's a daemon (service) */
        demon = win32_is_daemon(pid);

        /* Check username filtering */
        if ((psallusers || in_ps_userlist(psuser_list_head, username)) &&
            !(in_ps_userlist(psnotuser_list_head, username))) {
            add_to_pid_list(pid, procname, demon);
        }

    } while (Process32Next(hSnap, &pe32));

    CloseHandle(hSnap);
}

#endif /* _WIN32 */


/* =========================================================================
 * WINDOWS-SPECIFIC PROCESS KILLING
 *
 * This code block replaces the Linux system("kill -9 %d") implementation.
 * Insert this into pr_process.c, replacing or augmenting the pr_kill() function.
 * ========================================================================= */

#if defined(_WIN32) || defined(_WIN64)

/*
 * Windows implementation of pr_kill()
 * Uses TerminateProcess instead of system("kill -9")
 */
static void win32_pr_kill(int pid) {
    HANDLE hProc;
    PROCESSENTRY32 pe32;
    HANDLE hSnap;
    char procname[MAX_PATH] = "";

    /* If -nopsact was on the command line, don't actually kill the process */
    if (nopsact) {
        return;
    }

    /* Get process name for blacklist check */
    hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnap != INVALID_HANDLE_VALUE) {
        pe32.dwSize = sizeof(PROCESSENTRY32);
        if (Process32First(hSnap, &pe32)) {
            do {
                if (pe32.th32ProcessID == (DWORD)pid) {
                    strncpy(procname, pe32.szExeFile, MAX_PATH);
                    break;
                }
            } while (Process32Next(hSnap, &pe32));
        }
        CloseHandle(hSnap);
    }

    /* Check blacklist */
    if (win32_is_blacklisted(procname)) {
        fprintf(stderr, "pr_kill: Refusing to kill protected process '%s' (PID %d)\n",
                procname, pid);
        return;
    }

    /* Never kill our own process */
    if ((DWORD)pid == GetCurrentProcessId()) {
        fprintf(stderr, "pr_kill: Refusing to kill self\n");
        return;
    }

    /* Open the process with terminate rights */
    hProc = OpenProcess(PROCESS_TERMINATE, FALSE, (DWORD)pid);
    if (!hProc) {
        fprintf(stderr, "pr_kill: Cannot open process %d (error %lu)\n",
                pid, GetLastError());
        return;
    }

    /* Terminate the process */
    if (TerminateProcess(hProc, 1)) {
        fprintf(stderr, "pr_kill: Killed '%s' (PID %d)\n", procname, pid);
    } else {
        fprintf(stderr, "pr_kill: TerminateProcess failed for PID %d (error %lu)\n",
                pid, GetLastError());
    }

    CloseHandle(hProc);
}

#endif /* _WIN32 */


/* =========================================================================
 * WINDOWS-SPECIFIC PROCESS RENICING
 *
 * This code block replaces the Linux system("renice +5 %d") implementation.
 * Insert this into pr_process.c, replacing or augmenting the pr_renice() function.
 * ========================================================================= */

#if defined(_WIN32) || defined(_WIN64)

/*
 * Windows implementation of pr_renice()
 * Uses SetPriorityClass instead of system("renice +5")
 */
static void win32_pr_renice(int pid) {
    HANDLE hProc;
    DWORD currentPriority;
    DWORD newPriority;

    /* If -nopsact was on the command line, don't actually renice the process */
    if (nopsact) {
        return;
    }

    /* Never renice our own process */
    if ((DWORD)pid == GetCurrentProcessId()) {
        return;
    }

    /* Open the process with set information rights */
    hProc = OpenProcess(PROCESS_SET_INFORMATION | PROCESS_QUERY_INFORMATION,
                        FALSE, (DWORD)pid);
    if (!hProc) {
        fprintf(stderr, "pr_renice: Cannot open process %d (error %lu)\n",
                pid, GetLastError());
        return;
    }

    /* Get current priority */
    currentPriority = GetPriorityClass(hProc);

    /* Degrade priority one level */
    switch (currentPriority) {
        case REALTIME_PRIORITY_CLASS:
            newPriority = HIGH_PRIORITY_CLASS;
            break;
        case HIGH_PRIORITY_CLASS:
            newPriority = ABOVE_NORMAL_PRIORITY_CLASS;
            break;
        case ABOVE_NORMAL_PRIORITY_CLASS:
            newPriority = NORMAL_PRIORITY_CLASS;
            break;
        case NORMAL_PRIORITY_CLASS:
            newPriority = BELOW_NORMAL_PRIORITY_CLASS;
            break;
        case BELOW_NORMAL_PRIORITY_CLASS:
        case IDLE_PRIORITY_CLASS:
        default:
            newPriority = IDLE_PRIORITY_CLASS;
            break;
    }

    /* Set new priority */
    if (SetPriorityClass(hProc, newPriority)) {
        fprintf(stderr, "pr_renice: Lowered priority of PID %d\n", pid);
    } else {
        fprintf(stderr, "pr_renice: SetPriorityClass failed for PID %d (error %lu)\n",
                pid, GetLastError());
    }

    CloseHandle(hProc);
}

#endif /* _WIN32 */
