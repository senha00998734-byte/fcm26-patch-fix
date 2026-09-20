@echo off
setlocal
cd /d "%~dp0"
title FCM26 TU 1.6.6 COMPAT
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0FCM26_TU166_COMPAT.ps1"
if errorlevel 1 (
  echo.
  echo O reparo terminou com erro. Veja o arquivo DIAGNOSTICO gerado, se existir.
  pause
)
endlocal
