/*
 * Fight the Machine - Process Library Test Application
 *
 * Tests the Windows process handling library functions.
 * Run with --safe to enable safe mode (only kills decoy processes).
 */

#include "pr_process_win32.h"
#include <stdio.h>
#include <string.h>

void print_usage(const char* prog) {
    printf("Usage: %s [options]\n", prog);
    printf("\nOptions:\n");
    printf("  --list        List all processes\n");
    printf("  --kill <pid>  Kill a process by PID\n");
    printf("  --safe        Enable safe mode (only decoy processes)\n");
    printf("  --spawn       Spawn decoy processes for testing\n");
    printf("  --help        Show this help\n");
}

void list_processes(void) {
    pr_refresh_process_list();
    const ProcessList* list = pr_get_process_list();

    printf("\n%-8s %-30s %-15s %s\n", "PID", "NAME", "TIER", "STATUS");
    printf("-------- ------------------------------ --------------- --------\n");

    for (int i = 0; i < list->count; i++) {
        const ProcessInfo* p = &list->processes[i];
        printf("%-8lu %-30s %-15s %s\n",
               p->pid,
               p->name,
               pr_get_tier_name(p->tier),
               p->is_blacklisted ? "PROTECTED" : "");
    }

    printf("\nTotal: %d processes\n", list->count);
}

void spawn_decoys(void) {
    printf("Spawning decoy processes for safe testing...\n\n");

    DWORD pid1 = pr_spawn_decoy_process("notepad");
    DWORD pid2 = pr_spawn_decoy_process("calc");
    DWORD pid3 = pr_spawn_decoy_process("mspaint");

    printf("\nSpawned processes:\n");
    if (pid1) printf("  - notepad.exe (PID %lu)\n", pid1);
    if (pid2) printf("  - calc.exe (PID %lu)\n", pid2);
    if (pid3) printf("  - mspaint.exe (PID %lu)\n", pid3);

    printf("\nYou can now test killing these processes.\n");
}

int main(int argc, char* argv[]) {
    printf("Fight the Machine - Process Library Test\n");
    printf("========================================\n\n");

    /* Parse arguments */
    int do_list = 0;
    int do_spawn = 0;
    int safe_mode = 0;
    DWORD kill_pid = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--list") == 0) {
            do_list = 1;
        } else if (strcmp(argv[i], "--safe") == 0) {
            safe_mode = 1;
        } else if (strcmp(argv[i], "--spawn") == 0) {
            do_spawn = 1;
        } else if (strcmp(argv[i], "--kill") == 0 && i + 1 < argc) {
            kill_pid = (DWORD)atol(argv[++i]);
        } else if (strcmp(argv[i], "--help") == 0) {
            print_usage(argv[0]);
            return 0;
        }
    }

    /* Initialize library */
    if (pr_init() != 0) {
        fprintf(stderr, "Failed to initialize process library\n");
        return 1;
    }

    /* Set safe mode if requested */
    if (safe_mode) {
        pr_set_safe_mode(1);
    }

    /* Execute requested action */
    if (do_spawn) {
        spawn_decoys();
    }

    if (do_list) {
        list_processes();
    }

    if (kill_pid > 0) {
        printf("Attempting to kill PID %lu...\n", kill_pid);
        if (pr_kill_process(kill_pid) == 0) {
            printf("SUCCESS: Process killed\n");
        } else {
            printf("FAILED: Could not kill process (protected or error)\n");
        }
    }

    if (!do_list && !do_spawn && kill_pid == 0) {
        print_usage(argv[0]);
    }

    /* Cleanup */
    pr_shutdown();

    return 0;
}
