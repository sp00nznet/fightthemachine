# Fight the Machine - Native Windows Port of psDoom-ng
# CMake build system for Windows using MSYS2/MinGW or Visual Studio
#
# Prerequisites (MSYS2):
#   pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake \
#             mingw-w64-x86_64-SDL mingw-w64-x86_64-SDL_mixer \
#             mingw-w64-x86_64-SDL_net mingw-w64-x86_64-libpng
#
# Build:
#   mkdir build && cd build
#   cmake -G "MSYS Makefiles" ..
#   cmake --build . --parallel
#
# Or for Visual Studio:
#   cmake -G "Visual Studio 17 2022" -A x64 ..
#   cmake --build . --config Release

cmake_minimum_required(VERSION 3.16)
project(psdoom-ng VERSION 0.4.0 LANGUAGES C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Options
option(ENABLE_SAFE_MODE "Enable safe mode by default (only kill safe processes)" ON)
option(BUILD_NATIVE_KILLER "Build native Windows process killer" ON)

# =============================================================================
# Find dependencies
# =============================================================================
find_package(PkgConfig)

# SDL 1.2
if(PKG_CONFIG_FOUND)
    pkg_check_modules(SDL sdl)
    pkg_check_modules(SDL_MIXER SDL_mixer)
    pkg_check_modules(SDL_NET SDL_net)
endif()

if(NOT SDL_FOUND)
    find_path(SDL_INCLUDE_DIRS SDL/SDL.h)
    find_library(SDL_LIBRARIES SDL)
endif()

if(NOT SDL_MIXER_FOUND)
    find_library(SDL_MIXER_LIBRARIES SDL_mixer)
endif()

if(NOT SDL_NET_FOUND)
    find_library(SDL_NET_LIBRARIES SDL_net)
endif()

# libpng
find_package(PNG)

# Windows-specific settings
if(WIN32)
    add_definitions(-DWIN32 -D_WIN32 -D_CRT_SECURE_NO_WARNINGS)
    set(PLATFORM_LIBS psapi advapi32 ws2_32 winmm)
endif()

# Set source directory - this assumes psdoom-ng is cloned beside this CMakeLists.txt
# or you can set PSDOOM_SRC_DIR
if(NOT DEFINED PSDOOM_SRC_DIR)
    # Try to find the source relative to this CMakeLists.txt
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../psdoom-ng-src/trunk/src")
        set(PSDOOM_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../psdoom-ng-src/trunk/src")
    else()
        message(FATAL_ERROR "psdoom-ng source not found. Please set PSDOOM_SRC_DIR or clone psdoom-ng")
    endif()
endif()

message(STATUS "Using psdoom-ng source from: ${PSDOOM_SRC_DIR}")

# =============================================================================
# Common/Core source files
# =============================================================================
set(COMMON_SOURCES
    ${PSDOOM_SRC_DIR}/i_main.c
    ${PSDOOM_SRC_DIR}/i_system.c
    ${PSDOOM_SRC_DIR}/i_timer.c
    ${PSDOOM_SRC_DIR}/i_video.c
    ${PSDOOM_SRC_DIR}/i_videohr.c
    ${PSDOOM_SRC_DIR}/i_joystick.c
    ${PSDOOM_SRC_DIR}/i_scale.c
    ${PSDOOM_SRC_DIR}/i_sound.c
    ${PSDOOM_SRC_DIR}/i_sdlsound.c
    ${PSDOOM_SRC_DIR}/i_sdlmusic.c
    ${PSDOOM_SRC_DIR}/i_oplmusic.c
    ${PSDOOM_SRC_DIR}/i_pcsound.c
    ${PSDOOM_SRC_DIR}/i_cdmus.c
    ${PSDOOM_SRC_DIR}/i_endoom.c
    ${PSDOOM_SRC_DIR}/m_argv.c
    ${PSDOOM_SRC_DIR}/m_bbox.c
    ${PSDOOM_SRC_DIR}/m_cheat.c
    ${PSDOOM_SRC_DIR}/m_config.c
    ${PSDOOM_SRC_DIR}/m_controls.c
    ${PSDOOM_SRC_DIR}/m_fixed.c
    ${PSDOOM_SRC_DIR}/m_misc.c
    ${PSDOOM_SRC_DIR}/tables.c
    ${PSDOOM_SRC_DIR}/v_video.c
    ${PSDOOM_SRC_DIR}/w_checksum.c
    ${PSDOOM_SRC_DIR}/w_file.c
    ${PSDOOM_SRC_DIR}/w_file_stdc.c
    ${PSDOOM_SRC_DIR}/w_main.c
    ${PSDOOM_SRC_DIR}/w_merge.c
    ${PSDOOM_SRC_DIR}/w_wad.c
    ${PSDOOM_SRC_DIR}/z_zone.c
    ${PSDOOM_SRC_DIR}/d_event.c
    ${PSDOOM_SRC_DIR}/d_iwad.c
    ${PSDOOM_SRC_DIR}/d_loop.c
    ${PSDOOM_SRC_DIR}/d_mode.c
    ${PSDOOM_SRC_DIR}/sha1.c
    ${PSDOOM_SRC_DIR}/memio.c
    ${PSDOOM_SRC_DIR}/midifile.c
    ${PSDOOM_SRC_DIR}/mus2mid.c
    ${PSDOOM_SRC_DIR}/gusconf.c
    ${PSDOOM_SRC_DIR}/aes_prng.c
    ${PSDOOM_SRC_DIR}/deh_io.c
    ${PSDOOM_SRC_DIR}/deh_main.c
    ${PSDOOM_SRC_DIR}/deh_mapping.c
    ${PSDOOM_SRC_DIR}/deh_str.c
    ${PSDOOM_SRC_DIR}/deh_text.c
    # Network
    ${PSDOOM_SRC_DIR}/net_client.c
    ${PSDOOM_SRC_DIR}/net_common.c
    ${PSDOOM_SRC_DIR}/net_dedicated.c
    ${PSDOOM_SRC_DIR}/net_gui.c
    ${PSDOOM_SRC_DIR}/net_io.c
    ${PSDOOM_SRC_DIR}/net_loop.c
    ${PSDOOM_SRC_DIR}/net_packet.c
    ${PSDOOM_SRC_DIR}/net_query.c
    ${PSDOOM_SRC_DIR}/net_sdl.c
    ${PSDOOM_SRC_DIR}/net_server.c
    ${PSDOOM_SRC_DIR}/net_structrw.c
)

# Add Windows-specific file handling
if(WIN32)
    list(APPEND COMMON_SOURCES ${PSDOOM_SRC_DIR}/w_file_win32.c)
else()
    list(APPEND COMMON_SOURCES ${PSDOOM_SRC_DIR}/w_file_posix.c)
endif()

# =============================================================================
# Doom-specific source files
# =============================================================================
set(DOOM_SOURCES
    ${PSDOOM_SRC_DIR}/doom/am_map.c
    ${PSDOOM_SRC_DIR}/doom/d_items.c
    ${PSDOOM_SRC_DIR}/doom/d_main.c
    ${PSDOOM_SRC_DIR}/doom/d_net.c
    ${PSDOOM_SRC_DIR}/doom/doomdef.c
    ${PSDOOM_SRC_DIR}/doom/doomstat.c
    ${PSDOOM_SRC_DIR}/doom/dstrings.c
    ${PSDOOM_SRC_DIR}/doom/f_finale.c
    ${PSDOOM_SRC_DIR}/doom/f_wipe.c
    ${PSDOOM_SRC_DIR}/doom/g_game.c
    ${PSDOOM_SRC_DIR}/doom/hu_lib.c
    ${PSDOOM_SRC_DIR}/doom/hu_stuff.c
    ${PSDOOM_SRC_DIR}/doom/info.c
    ${PSDOOM_SRC_DIR}/doom/m_menu.c
    ${PSDOOM_SRC_DIR}/doom/m_random.c
    ${PSDOOM_SRC_DIR}/doom/p_ceilng.c
    ${PSDOOM_SRC_DIR}/doom/p_doors.c
    ${PSDOOM_SRC_DIR}/doom/p_enemy.c
    ${PSDOOM_SRC_DIR}/doom/p_floor.c
    ${PSDOOM_SRC_DIR}/doom/p_inter.c
    ${PSDOOM_SRC_DIR}/doom/p_lights.c
    ${PSDOOM_SRC_DIR}/doom/p_map.c
    ${PSDOOM_SRC_DIR}/doom/p_maputl.c
    ${PSDOOM_SRC_DIR}/doom/p_mobj.c
    ${PSDOOM_SRC_DIR}/doom/p_plats.c
    ${PSDOOM_SRC_DIR}/doom/p_pspr.c
    ${PSDOOM_SRC_DIR}/doom/p_saveg.c
    ${PSDOOM_SRC_DIR}/doom/p_setup.c
    ${PSDOOM_SRC_DIR}/doom/p_sight.c
    ${PSDOOM_SRC_DIR}/doom/p_spec.c
    ${PSDOOM_SRC_DIR}/doom/p_switch.c
    ${PSDOOM_SRC_DIR}/doom/p_telept.c
    ${PSDOOM_SRC_DIR}/doom/p_tick.c
    ${PSDOOM_SRC_DIR}/doom/p_user.c
    # Use our Windows-patched pr_process.c
    ${CMAKE_CURRENT_SOURCE_DIR}/pr_process.c
    ${PSDOOM_SRC_DIR}/doom/r_bsp.c
    ${PSDOOM_SRC_DIR}/doom/r_data.c
    ${PSDOOM_SRC_DIR}/doom/r_draw.c
    ${PSDOOM_SRC_DIR}/doom/r_main.c
    ${PSDOOM_SRC_DIR}/doom/r_plane.c
    ${PSDOOM_SRC_DIR}/doom/r_segs.c
    ${PSDOOM_SRC_DIR}/doom/r_sky.c
    ${PSDOOM_SRC_DIR}/doom/r_things.c
    ${PSDOOM_SRC_DIR}/doom/s_sound.c
    ${PSDOOM_SRC_DIR}/doom/sounds.c
    ${PSDOOM_SRC_DIR}/doom/st_lib.c
    ${PSDOOM_SRC_DIR}/doom/st_stuff.c
    ${PSDOOM_SRC_DIR}/doom/statdump.c
    ${PSDOOM_SRC_DIR}/doom/wi_stuff.c
    # DEH files
    ${PSDOOM_SRC_DIR}/doom/deh_ammo.c
    ${PSDOOM_SRC_DIR}/doom/deh_bexstr.c
    ${PSDOOM_SRC_DIR}/doom/deh_cheat.c
    ${PSDOOM_SRC_DIR}/doom/deh_doom.c
    ${PSDOOM_SRC_DIR}/doom/deh_frame.c
    ${PSDOOM_SRC_DIR}/doom/deh_misc.c
    ${PSDOOM_SRC_DIR}/doom/deh_ptr.c
    ${PSDOOM_SRC_DIR}/doom/deh_sound.c
    ${PSDOOM_SRC_DIR}/doom/deh_thing.c
    ${PSDOOM_SRC_DIR}/doom/deh_weapon.c
)

# =============================================================================
# OPL library (FM Synthesizer for music)
# =============================================================================
set(OPL_SOURCES
    ${PSDOOM_SRC_DIR}/../opl/opl.c
    ${PSDOOM_SRC_DIR}/../opl/opl_queue.c
    ${PSDOOM_SRC_DIR}/../opl/opl_sdl.c
    ${PSDOOM_SRC_DIR}/../opl/opl_timer.c
    ${PSDOOM_SRC_DIR}/../opl/dbopl.c
)
# Add platform-specific OPL files
if(NOT WIN32)
    list(APPEND OPL_SOURCES
        ${PSDOOM_SRC_DIR}/../opl/opl_linux.c
        ${PSDOOM_SRC_DIR}/../opl/opl_obsd.c
        ${PSDOOM_SRC_DIR}/../opl/ioperm_sys.c
    )
endif()

add_library(opl STATIC ${OPL_SOURCES})
target_include_directories(opl PRIVATE
    ${PSDOOM_SRC_DIR}/../opl
    ${PSDOOM_SRC_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${SDL_INCLUDE_DIRS}
)
target_compile_definitions(opl PRIVATE HAVE_CONFIG_H)

# =============================================================================
# PC Sound library
# =============================================================================
set(PCSOUND_SOURCES
    ${PSDOOM_SRC_DIR}/../pcsound/pcsound.c
    ${PSDOOM_SRC_DIR}/../pcsound/pcsound_sdl.c
)
# Add platform-specific pcsound files
if(WIN32)
    list(APPEND PCSOUND_SOURCES ${PSDOOM_SRC_DIR}/../pcsound/pcsound_win32.c)
else()
    list(APPEND PCSOUND_SOURCES ${PSDOOM_SRC_DIR}/../pcsound/pcsound_linux.c)
endif()

add_library(pcsound STATIC ${PCSOUND_SOURCES})
target_include_directories(pcsound PRIVATE
    ${PSDOOM_SRC_DIR}/../pcsound
    ${PSDOOM_SRC_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${SDL_INCLUDE_DIRS}
)
target_compile_definitions(pcsound PRIVATE HAVE_CONFIG_H)

# =============================================================================
# Textscreen library
# =============================================================================
set(TEXTSCREEN_SOURCES
    ${PSDOOM_SRC_DIR}/../textscreen/txt_button.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_checkbox.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_desktop.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_dropdown.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_gui.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_inputbox.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_io.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_label.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_radiobutton.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_scrollpane.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_sdl.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_separator.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_spinctrl.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_strut.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_table.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_widget.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_window.c
    ${PSDOOM_SRC_DIR}/../textscreen/txt_window_action.c
)

add_library(textscreen STATIC ${TEXTSCREEN_SOURCES})
target_include_directories(textscreen PRIVATE
    ${PSDOOM_SRC_DIR}/../textscreen
    ${PSDOOM_SRC_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${SDL_INCLUDE_DIRS}
)
target_compile_definitions(textscreen PRIVATE HAVE_CONFIG_H)

# =============================================================================
# Main executable - psdoom-ng
# =============================================================================
add_executable(psdoom-ng WIN32
    ${COMMON_SOURCES}
    ${DOOM_SOURCES}
)

# Include directories
target_include_directories(psdoom-ng PRIVATE
    ${PSDOOM_SRC_DIR}
    ${PSDOOM_SRC_DIR}/doom
    ${PSDOOM_SRC_DIR}/../opl
    ${PSDOOM_SRC_DIR}/../pcsound
    ${PSDOOM_SRC_DIR}/../textscreen
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${SDL_INCLUDE_DIRS}
    ${PNG_INCLUDE_DIRS}
)

# Use our config.h for Windows builds
if(WIN32)
    target_compile_definitions(psdoom-ng PRIVATE
        HAVE_CONFIG_H
    )
endif()

# Link libraries
target_link_libraries(psdoom-ng PRIVATE
    textscreen
    opl
    pcsound
    ${SDL_LIBRARIES}
    ${SDL_MIXER_LIBRARIES}
    ${SDL_NET_LIBRARIES}
    ${PNG_LIBRARIES}
    ${PLATFORM_LIBS}
)

# Safe mode option
if(ENABLE_SAFE_MODE)
    target_compile_definitions(psdoom-ng PRIVATE PSDOOM_SAFE_MODE_DEFAULT=1)
else()
    target_compile_definitions(psdoom-ng PRIVATE PSDOOM_SAFE_MODE_DEFAULT=0)
endif()

# =============================================================================
# Copy required files
# =============================================================================

# Copy WAD files if they exist
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../wad")
    file(COPY "${CMAKE_CURRENT_SOURCE_DIR}/../../wad/"
         DESTINATION "${CMAKE_BINARY_DIR}/wad")
endif()

# =============================================================================
# Install rules
# =============================================================================
install(TARGETS psdoom-ng DESTINATION bin)

# Install WAD files
install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../../wad/"
        DESTINATION share/psdoom-ng
        FILES_MATCHING PATTERN "*.wad")

# =============================================================================
# CPack configuration
# =============================================================================
set(CPACK_GENERATOR "ZIP")
set(CPACK_PACKAGE_NAME "FightTheMachine-Native")
set(CPACK_PACKAGE_VENDOR "Fight the Machine Project")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Native Windows port of psDoom-ng - Kill real Windows processes as DOOM monsters")
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
include(CPack)

message(STATUS "")
message(STATUS "===========================================")
message(STATUS "Fight the Machine - Native Windows Build")
message(STATUS "===========================================")
message(STATUS "")
message(STATUS "This build will create a NATIVE Windows executable")
message(STATUS "that kills REAL Windows processes when you kill")
message(STATUS "monsters in DOOM!")
message(STATUS "")
message(STATUS "Safe mode: ${ENABLE_SAFE_MODE}")
message(STATUS "")
message(STATUS "WARNING: This software can terminate any Windows")
message(STATUS "         process. Use with caution!")
message(STATUS "")
