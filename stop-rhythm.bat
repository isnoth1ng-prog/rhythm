@echo off
tailscale funnel reset
taskkill /FI "WINDOWTITLE eq Rhythm Backend*" /T /F >nul 2>&1
echo Rhythm backend and public tunnel stopped.
pause
