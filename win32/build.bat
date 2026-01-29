@echo off
REM Fight the Machine - Win32 Build Script (Batch wrapper)
REM Calls PowerShell build script with arguments

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%build.ps1"

REM Parse arguments
set "ARGS="
:parse_args
if "%~1"=="" goto run
if /i "%~1"=="clean" set "ARGS=!ARGS! -Clean"
if /i "%~1"=="release" set "ARGS=!ARGS! -Release"
if /i "%~1"=="package" set "ARGS=!ARGS! -Package"
if /i "%~1"=="help" goto show_help
if /i "%~1"=="-h" goto show_help
if /i "%~1"=="/?" goto show_help
shift
goto parse_args

:run
echo Running: powershell -ExecutionPolicy Bypass -File "%PS_SCRIPT%"%ARGS%
powershell -ExecutionPolicy Bypass -File "%PS_SCRIPT%"%ARGS%
goto end

:show_help
echo.
echo Fight the Machine - Win32 Build Script
echo.
echo Usage: build.bat [options]
echo.
echo Options:
echo   clean     Clean build directory before building
echo   release   Build in Release mode (default: Debug)
echo   package   Create installer package after build
echo   help      Show this help message
echo.
echo Examples:
echo   build.bat                    Build Debug version
echo   build.bat release            Build Release version
echo   build.bat clean release      Clean and build Release
echo   build.bat release package    Build Release and create installer
echo.
goto end

:end
endlocal
