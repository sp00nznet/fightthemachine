/*
 * Fight the Machine - Native Windows Process Handling
 * Header file for Windows Toolhelp32 process management
 *
 * This file provides the interface for psDoom-ng to interact with
 * Windows processes using the Toolhelp32 API.
 */

#ifndef PR_PROCESS_WIN32_H
#define PR_PROCESS_WIN32_H

#ifdef __cplusplus
extern "C" {
#endif

#include <windows.h>
#include <tlhelp32.h>

/* Maximum number of processes to track */
#define MAX_PROCESSES 256

/* Maximum process name length */
#define MAX_PROC_NAME 260

/* Process priority levels (DOOM enemy tiers) */
typedef enum {
    TIER_ZOMBIEMAN = 0,   /* Basic processes (notepad, calc) */
    TIER_IMP,             /* Development tools (code, node) */
    TIER_DEMON,           /* Desktop apps (chrome, discord) */
    TIER_CACODEMON,       /* Background services */
    TIER_BARON,           /* Important apps (explorer excluded) */
    TIER_CYBERDEMON       /* Protected - will not be killed */
} ProcessTier;

/* Process information structure */
typedef struct {
    DWORD pid;
    char name[MAX_PROC_NAME];
    ProcessTier tier;
    int is_blacklisted;
    DWORD parent_pid;
    SIZE_T memory_usage;
} ProcessInfo;

/* Process list structure */
typedef struct {
    ProcessInfo processes[MAX_PROCESSES];
    int count;
} ProcessList;

/*
 * Initialize the process manager
 * Returns: 0 on success, -1 on failure
 */
int pr_init(void);

/*
 * Shutdown the process manager
 */
void pr_shutdown(void);

/*
 * Refresh the list of running processes
 * Returns: Number of processes found, -1 on error
 */
int pr_refresh_process_list(void);

/*
 * Get the current process list
 * Returns: Pointer to the process list
 */
const ProcessList* pr_get_process_list(void);

/*
 * Get process information by PID
 * Returns: Pointer to ProcessInfo, or NULL if not found
 */
const ProcessInfo* pr_get_process_info(DWORD pid);

/*
 * Kill a process by PID
 * Returns: 0 on success, -1 on failure (protected or error)
 */
int pr_kill_process(DWORD pid);

/*
 * Lower the priority of a process (renice equivalent)
 * Returns: 0 on success, -1 on failure
 */
int pr_renice_process(DWORD pid);

/*
 * Check if a process is blacklisted (protected)
 * Returns: 1 if blacklisted, 0 otherwise
 */
int pr_is_blacklisted(const char* process_name);

/*
 * Get the tier (DOOM enemy type) for a process
 * Returns: ProcessTier enum value
 */
ProcessTier pr_get_process_tier(const char* process_name);

/*
 * Get a human-readable name for a tier
 * Returns: Static string with tier name
 */
const char* pr_get_tier_name(ProcessTier tier);

/*
 * Enable or disable safe mode (only kills decoy processes)
 */
void pr_set_safe_mode(int enabled);

/*
 * Check if safe mode is enabled
 * Returns: 1 if safe mode, 0 otherwise
 */
int pr_is_safe_mode(void);

/*
 * Spawn a decoy process for safe mode testing
 * Returns: PID of spawned process, 0 on failure
 */
DWORD pr_spawn_decoy_process(const char* name);

#ifdef __cplusplus
}
#endif

#endif /* PR_PROCESS_WIN32_H */
