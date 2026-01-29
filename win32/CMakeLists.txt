cmake_minimum_required(VERSION 3.16)
project(FightTheMachine VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Windows-specific settings
if(WIN32)
    set(CMAKE_WIN32_EXECUTABLE ON)
    add_definitions(-DUNICODE -D_UNICODE)
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

# Create executable
add_executable(fightthemachine WIN32 ${SOURCES})

# Include directories
target_include_directories(fightthemachine PRIVATE
    ${webview2_SOURCE_DIR}/build/native/include
    ${wil_SOURCE_DIR}/include
)

# Link libraries
target_link_libraries(fightthemachine PRIVATE
    ${webview2_SOURCE_DIR}/build/native/x64/WebView2LoaderStatic.lib
    shlwapi
    shell32
    ole32
    oleaut32
    uuid
)

# Copy WebView2Loader.dll to output directory (for dynamic linking alternative)
add_custom_command(TARGET fightthemachine POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
    "${webview2_SOURCE_DIR}/build/native/x64/WebView2Loader.dll"
    $<TARGET_FILE_DIR:fightthemachine>
)

# Copy docker-compose.yml to output directory so exe can find it
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

# Copy WAD files
add_custom_command(TARGET fightthemachine POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
    "${CMAKE_SOURCE_DIR}/../wad"
    "$<TARGET_FILE_DIR:fightthemachine>/wad"
)

# Install rules
install(TARGETS fightthemachine DESTINATION bin)
install(FILES
    "${webview2_SOURCE_DIR}/build/native/x64/WebView2Loader.dll"
    DESTINATION bin
)

# Package configuration for CPack
set(CPACK_GENERATOR "ZIP;NSIS")
set(CPACK_PACKAGE_NAME "FightTheMachine")
set(CPACK_PACKAGE_VENDOR "sp00nz.net")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Kill processes as DOOM monsters")
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/../LICENSE")
include(CPack)
