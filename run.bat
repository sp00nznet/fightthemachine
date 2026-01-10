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
    echo ERROR: Docker is not installed.
    echo Please install Docker Desktop: https://docs.docker.com/desktop/windows/install/
    pause
    exit /b 1
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
