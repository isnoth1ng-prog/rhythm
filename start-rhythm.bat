@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo.
echo  ==========================================
echo       RHYTHM - Windows Backend
echo  ==========================================
echo.

where py >nul 2>&1
if errorlevel 1 (
    echo [1/4] Python not found. Installing Python 3.12...
    winget install --id Python.Python.3.12 -e --accept-source-agreements --accept-package-agreements
    if errorlevel 1 (
        echo Python installation failed.
        pause
        exit /b 1
    )
)

where tailscale >nul 2>&1
if errorlevel 1 (
    echo [2/4] Tailscale not found. Installing...
    winget install --id Tailscale.Tailscale -e --accept-source-agreements --accept-package-agreements
    if errorlevel 1 (
        echo Tailscale installation failed.
        echo Install Tailscale from https://tailscale.com/download/windows and run this file again.
        pause
        exit /b 1
    )
)

echo [3/4] Installing backend dependencies...
py -3.12 -m pip install --disable-pip-version-check -r Backend\requirements.txt
if errorlevel 1 (
    echo Dependency installation failed.
    pause
    exit /b 1
)

echo [4/4] Checking Tailscale login...
tailscale status >nul 2>&1
if errorlevel 1 (
    echo.
    echo Tailscale needs a one-time login. A browser window will open.
    tailscale login
    if errorlevel 1 (
        echo Tailscale login failed.
        pause
        exit /b 1
    )
)

echo.
echo Starting Rhythm backend on localhost:8080...
start "Rhythm Backend" /min cmd /c "py -3.12 -m uvicorn Backend.app:app --host 127.0.0.1 --port 8080"

timeout /t 3 /nobreak >nul

echo Starting public HTTPS tunnel...
tailscale set --hostname=rhythm
tailscale funnel --bg 8080
if errorlevel 1 (
    echo.
    echo Funnel could not be enabled automatically.
    echo Tailscale may need one-time approval in your browser/admin console.
    echo Run: tailscale funnel 8080
    pause
    exit /b 1
)

echo.
echo ==========================================
echo Rhythm is available from the internet:
echo.
tailscale funnel status
echo.
echo Keep this PC switched on.
echo ==========================================
echo.
pause
