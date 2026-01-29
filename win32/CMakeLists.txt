cmake_minimum_required(VERSION 3.16)
project(FightTheMachine VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Build options
option(USE_QEMU "Build with QEMU embedded support" OFF)
option(USE_DOCKER "Build with Docker support (legacy)" ON)

# Windows-specific settings
if(WIN32)
    set(CMAKE_WIN32_EXECUTABLE ON)
    add_definitions(-DUNICODE -D_UNICODE)
endif()

# Add QEMU support if enabled
if(USE_QEMU)
    add_definitions(-DUSE_QEMU)
    message(STATUS "QEMU support enabled")
endif()

# Find WebView2 NuGet package
include(FetchContent)
FetchContent_Declare(
    webview2
    URL https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/1.0.2210.55
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_MakeAvailable(webview2)

# Find Windows Implementation Libraries (WIL)
FetchContent_Declare(
    wil
    URL https://www.nuget.org/api/v2/package/Microsoft.Windows.ImplementationLibrary/1.0.231216.1
    DOWNLOAD_EXTRACT_TIMESTAMP TRUE
)
FetchContent_MakeAvailable(wil)

# Source files
set(SOURCES
    main.cpp
    app.rc
)

# Add QEMU manager if enabled
if(USE_QEMU)
    list(APPEND SOURCES
        qemu_manager.cpp
        qemu_manager.h
    )
endif()

# Create executable
add_executable(fightthemachine WIN32 ${SOURCES})

# Use our custom manifest
if(MSVC)
    set_target_properties(fightthemachine PROPERTIES
        LINK_FLAGS "/MANIFEST:EMBED /MANIFESTINPUT:\"${CMAKE_CURRENT_SOURCE_DIR}/app.manifest\""
    )
endif()

# Include directories
target_include_directories(fightthemachine PRIVATE
    ${webview2_SOURCE_DIR}/build/native/include
    ${wil_SOURCE_DIR}/include
)

# Link libraries
set(LINK_LIBS
    ${webview2_SOURCE_DIR}/build/native/x64/WebView2LoaderStatic.lib
    shlwapi
    shell32
    ole32
    oleaut32
    uuid
)

# Add winhttp for QEMU health checks
if(USE_QEMU)
    list(APPEND LINK_LIBS winhttp)
endif()

target_link_libraries(fightthemachine PRIVATE ${LINK_LIBS})

# Copy WebView2Loader.dll to output directory (for dynamic linking alternative)
add_custom_command(TARGET fightthemachine POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${webview2_SOURCE_DIR}/build/native/x64/WebView2Loader.dll"
    $<TARGET_FILE_DIR:fightthemachine>
)

# Copy docker-compose.yml to output directory (for Docker mode)
if(USE_DOCKER AND EXISTS "${CMAKE_SOURCE_DIR}/../docker-compose.yml")
    add_custom_command(TARGET fightthemachine POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_SOURCE_DIR}/../docker-compose.yml"
        $<TARGET_FILE_DIR:fightthemachine>
    )

    # Copy Dockerfile to output directory
    add_custom_command(TARGET fightthemachine POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/../docker"
        "$<TARGET_FILE_DIR:fightthemachine>/docker"
    )
endif()

# Copy WAD files
if(EXISTS "${CMAKE_SOURCE_DIR}/../wad")
    add_custom_command(TARGET fightthemachine POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/../wad"
        "$<TARGET_FILE_DIR:fightthemachine>/wad"
    )
endif()

# Create QEMU and VM directories for QEMU builds
if(USE_QEMU)
    add_custom_command(TARGET fightthemachine POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:fightthemachine>/qemu"
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:fightthemachine>/vm"
    )
endif()

# Install rules
install(TARGETS fightthemachine DESTINATION bin)
install(FILES
    "${webview2_SOURCE_DIR}/build/native/x64/WebView2Loader.dll"
    DESTINATION bin
)

# Package configuration for CPack
set(CPACK_GENERATOR "ZIP")
set(CPACK_PACKAGE_NAME "FightTheMachine")
set(CPACK_PACKAGE_VENDOR "sp00nz.net")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Kill processes as DOOM monsters")
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})

# Add QEMU or Docker suffix to package name
if(USE_QEMU)
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-QEMU-${PROJECT_VERSION}")
else()
    set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-Docker-${PROJECT_VERSION}")
endif()

if(EXISTS "${CMAKE_SOURCE_DIR}/../LICENSE")
    set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/../LICENSE")
endif()
include(CPack)
