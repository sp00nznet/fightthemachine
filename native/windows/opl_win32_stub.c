/* opl_win32_stub.c - Stub for opl_win32_driver
 *
 * The real opl_win32.c requires direct I/O port access via ioperm_sys.c
 * which needs a kernel driver. Since we use SDL for audio (via opl_sdl.c),
 * we just provide a stub that always fails so it falls back to SDL.
 */

#include "opl.h"
#include "opl_internal.h"

static int OPL_Win32_Init(unsigned int port_base)
{
    /* Always fail - we don't support direct hardware OPL on Windows */
    /* The SDL-based OPL emulator will be used instead */
    return 0;
}

static void OPL_Win32_Shutdown(void)
{
    /* Nothing to do */
}

static unsigned int OPL_Win32_PortRead(opl_port_t port)
{
    return 0;
}

static void OPL_Win32_PortWrite(opl_port_t port, unsigned int value)
{
    /* Nothing to do */
}

static void OPL_Win32_SetCallback(uint64_t us, opl_callback_t callback, void *data)
{
    /* Nothing to do */
}

static void OPL_Win32_ClearCallbacks(void)
{
    /* Nothing to do */
}

static void OPL_Win32_Lock(void)
{
    /* Nothing to do */
}

static void OPL_Win32_Unlock(void)
{
    /* Nothing to do */
}

static void OPL_Win32_SetPaused(int paused)
{
    /* Nothing to do */
}

static void OPL_Win32_AdjustCallbacks(float factor)
{
    /* Nothing to do */
}

opl_driver_t opl_win32_driver =
{
    "Win32",
    OPL_Win32_Init,
    OPL_Win32_Shutdown,
    OPL_Win32_PortRead,
    OPL_Win32_PortWrite,
    OPL_Win32_SetCallback,
    OPL_Win32_ClearCallbacks,
    OPL_Win32_Lock,
    OPL_Win32_Unlock,
    OPL_Win32_SetPaused,
    OPL_Win32_AdjustCallbacks,
};
