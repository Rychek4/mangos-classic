@echo off
REM One click: everything except the client data extraction, which needs
REM your WoW 1.12.1 folder and runs for hours. FIRST_RUN.md covers that.
setlocal
echo.
echo   Setting up the Azeroth server. Two steps, a few minutes.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Databases.ps1" %*
if errorlevel 1 goto :failed
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Configs.ps1" %*
if errorlevel 1 goto :failed
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Test-Setup.ps1" %*
echo.
echo   Done. Anything marked STOP above still needs doing.
pause
exit /b 0

:failed
echo.
echo   Stopped. The lines above say why. Nothing later was run.
pause
exit /b 1
