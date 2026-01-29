/*
 * Fight the Machine - Process Blacklist
 * Critical system processes that must NEVER be terminated
 *
 * SECURITY CRITICAL: This file defines processes that are protected
 * from being killed by the game. Modifying this list incorrectly
 * can cause system instability or crashes.
 */

#ifndef PROCESS_BLACKLIST_H
#define PROCESS_BLACKLIST_H

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Check if a process name is in the blacklist
 * Returns: 1 if blacklisted (protected), 0 otherwise
 */
int is_process_blacklisted(const char* process_name);

/*
 * Get the blacklist as a null-terminated array
 * Returns: Pointer to static array of blacklisted process names
 */
const char** get_blacklist(void);

/*
 * Get the reason why a process is blacklisted
 * Returns: Static string with reason, or NULL if not blacklisted
 */
const char* get_blacklist_reason(const char* process_name);

#ifdef __cplusplus
}
#endif

#endif /* PROCESS_BLACKLIST_H */
