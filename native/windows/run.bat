@echo off
setlocal enabledelayedexpansion

echo ============================================
echo  Fight the Machine - Native Windows Build
echo ============================================
echo.
echo WARNING: This will kill REAL Windows processes!
echo.

:: Read config file
set SCALE=2
set WINDOWED=1
set SAFE_MODE=1

if exist fightthemachine.cfg (
    for /f "tokens=1,2 delims==" %%a in ('type fightthemachine.cfg ^| findstr /v "^#" ^| findstr "="') do (
        set %%a=%%b
    )
)

:: Build command line arguments
:: No -iwad: the engine picks up doom2.wad, doom.wad or doom1.wad beside the exe.
set ARGS=

:: Add scale factor
if "%SCALE%"=="2" set ARGS=%ARGS% -2
if "%SCALE%"=="3" set ARGS=%ARGS% -3
if "%SCALE%"=="4" set ARGS=%ARGS% -4
if "%SCALE%"=="5" set ARGS=%ARGS% -5
if "%SCALE%"=="6" set ARGS=%ARGS% -6

:: Add windowed mode
if "%WINDOWED%"=="1" set ARGS=%ARGS% -window

:: Safe mode is on in the exe; only an explicit 0 lifts it
if "%SAFE_MODE%"=="0" set ARGS=%ARGS% -unsafe

:: Display settings
echo Current settings (edit fightthemachine.cfg to change):
echo   Scale: %SCALE%x
echo   Windowed: %WINDOWED%
echo   Safe Mode: %SAFE_MODE%
echo.
echo Press any key to start, or Ctrl+C to cancel...
pause > nul

:: Launch the game
fightthemachine.exe %ARGS%
