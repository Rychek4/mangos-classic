@echo off
REM One click: starts the login server and the world server.
REM The world server ends up in this window, which is where you type
REM   account create <name> <password>
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-Server.ps1" %*
if errorlevel 1 (
  echo.
  echo The server stopped with an error. The lines above say why.
  pause
)
