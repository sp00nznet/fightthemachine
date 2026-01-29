# Fight the Machine - Native Windows Port
# Builds psDoom-ng with native Windows process handling
#
# This CMakeLists.txt builds:
# 1. Process handling library (pr_process_win32)
# 2. Process respawner daemon
# 3. (Optional) Full psDoom-ng with Windows process support

cmake_minimum_required(VERSION 3.16)
project(FightTheMachineNative VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Windows-specific settings
if(WIN32)
    add_definitions(-DUNICODE -D_UNICODE -D_CRT_SECURE_NO_WARNINGS)
endif()

# Build options
option(BUILD_RESPAWNER "Build the process respawner daemon" ON)
option(BUILD_TEST_APP "Build test application for process library" ON)

# =============================================================================
# Process Handling Library
# =============================================================================
add_library(pr_process_win32 STATIC
    pr_process_win32.c
    pr_process_win32.h
    process_blacklist.c
    process_blacklist.h
)

target_link_libraries(pr_process_win32 PRIVATE
    psapi
)

# =============================================================================
# Process Respawner Daemon
# =============================================================================
if(BUILD_RESPAWNER)
    add_executable(process-respawner
        respawner/main.cpp
    )

    target_link_libraries(process-respawner PRIVATE
        psapi
    )

    # Run as console application
    set_target_properties(process-respawner PROPERTIES
        WIN32_EXECUTABLE FALSE
    )
endif()

# =============================================================================
# Test Application
# =============================================================================
if(BUILD_TEST_APP)
    add_executable(test-process-lib
        test_process_lib.c
    )

    target_link_libraries(test-process-lib PRIVATE
        pr_process_win32
        psapi
    )

    set_target_properties(test-process-lib PROPERTIES
        WIN32_EXECUTABLE FALSE
    )
endif()

# =============================================================================
# Install Rules
# =============================================================================
install(TARGETS pr_process_win32
    ARCHIVE DESTINATION lib
)

install(FILES
    pr_process_win32.h
    process_blacklist.h
    DESTINATION include
)

if(BUILD_RESPAWNER)
    install(TARGETS process-respawner DESTINATION bin)
endif()

# =============================================================================
# CPack Configuration
# =============================================================================
set(CPACK_GENERATOR "ZIP")
set(CPACK_PACKAGE_NAME "FightTheMachine-Native")
set(CPACK_PACKAGE_VENDOR "sp00nz.net")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Native Windows process handling for psDoom-ng")
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
include(CPack)
