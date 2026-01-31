/* config.h - Generated for MinGW/GCC Windows builds */

#ifndef CONFIG_H
#define CONFIG_H

/* Package information */
#define PACKAGE "psdoom-ng"
#define PACKAGE_NAME "psDoom-ng"
#define PACKAGE_STRING "psDoom-ng 0.4.0"
#define PACKAGE_TARNAME "psdoom-ng"
#define PACKAGE_VERSION "0.4.0"
#define VERSION "0.4.0"
#define PROGRAM_PREFIX ""

/* Windows platform */
#define _WIN32 1

/* Standard headers available in MinGW */
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_MEMORY_H 1
#define HAVE_STDINT_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_UNISTD_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_STAT_H 1

/* Functions - don't define HAVE_MMAP on Windows (we use win32 file API) */
/* #undef HAVE_MMAP */
/* #undef HAVE_IOPERM */
/* #undef HAVE_SCHED_SETAFFINITY */

/* Libraries - these are detected by CMake */
#define HAVE_LIBSDL 1
#define HAVE_LIBSDL_MIXER 1
#define HAVE_LIBSDL_NET 1
#define HAVE_LIBPNG 1

/* Networking */
#define HAVE_WINSOCK 1

#endif /* CONFIG_H */
