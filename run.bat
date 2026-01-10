@echo off
setlocal enabledelayedexpansion

:: Fight the Machine - Quick Start Script for Windows
:: Run this script to build and start Fight the Machine in a Docker container

cd /d "%~dp0"

echo.
echo ============================================================
echo              Fight the Machine
echo     Kill processes as DOOM monsters in your browser!
echo ============================================================
echo.

:: Check for Docker
where docker >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo Docker is not installed.
    echo.
    set /p INSTALL_DOCKER="Would you like to download and install Docker Desktop? [Y/n] "
    if /i "!INSTALL_DOCKER!"=="n" (
        echo.
        echo Docker is required to run Fight the Machine.
        echo Download manually from: https://docs.docker.com/desktop/windows/install/
        pause
        exit /b 1
    )
    echo.
    echo Downloading Docker Desktop installer...
    set "DOCKER_INSTALLER=%TEMP%\DockerDesktopInstaller.exe"
    powershell -Command "& {[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri 'https://desktop.docker.com/win/main/amd64/Docker%%20Desktop%%20Installer.exe' -OutFile '!DOCKER_INSTALLER!' -UseBasicParsing}"
    if not exist "!DOCKER_INSTALLER!" (
        echo.
        echo ERROR: Failed to download Docker Desktop installer.
        echo Please download manually from: https://docs.docker.com/desktop/windows/install/
        pause
        exit /b 1
    )
    echo.
    echo Download complete. Starting Docker Desktop installer...
    echo Please follow the installation prompts.
    echo.
    start /wait "" "!DOCKER_INSTALLER!" install --quiet
    del "!DOCKER_INSTALLER!" 2>nul
    echo.
    echo Docker Desktop installation complete.
    echo.
    echo IMPORTANT: You need to:
    echo   1. Restart your computer (recommended) or log out and back in
    echo   2. Start Docker Desktop from the Start menu
    echo   3. Wait for Docker to fully start (icon in system tray)
    echo   4. Run this script again
    echo.
    pause
    exit /b 0
)

:: Set default action
set ACTION=%1
if "%ACTION%"=="" set ACTION=start

:: Handle actions
if /i "%ACTION%"=="start" goto :start
if /i "%ACTION%"=="up" goto :start
if /i "%ACTION%"=="stop" goto :stop
if /i "%ACTION%"=="down" goto :stop
if /i "%ACTION%"=="restart" goto :restart
if /i "%ACTION%"=="logs" goto :logs
if /i "%ACTION%"=="status" goto :status
if /i "%ACTION%"=="build" goto :build
if /i "%ACTION%"=="shell" goto :shell
goto :usage

:start
echo Building and starting Fight the Machine container...
docker compose up -d --build
echo.
echo Fight the Machine is starting up!
echo.
echo Access the game in your browser at:
echo   http://localhost:6080
echo.
echo Wait ~30 seconds for the container to fully initialize.
echo.
echo Commands:
echo   run.bat stop     - Stop the container
echo   run.bat logs     - View container logs
echo   run.bat restart  - Restart the container
echo   run.bat status   - Check container status
goto :end

:stop
echo Stopping container...
docker compose down
echo Container stopped.
goto :end

:restart
echo Restarting container...
docker compose restart
echo Container restarted.
goto :end

:logs
echo Showing container logs (Ctrl+C to exit)...
docker compose logs -f
goto :end

:status
echo Container status:
docker compose ps
goto :end

:build
echo Building container...
docker compose build --no-cache
echo Build complete.
goto :end

:shell
echo Opening shell in container...
docker exec -it fightthemachine /bin/bash
goto :end

:usage
echo Usage: run.bat [command]
echo.
echo Commands:
echo   start   - Build and start the container (default)
echo   stop    - Stop the container
echo   restart - Restart the container
echo   logs    - View container logs
echo   status  - Show container status
echo   build   - Rebuild the container image
echo   shell   - Open a shell in the container
goto :end

:end
endlocal
