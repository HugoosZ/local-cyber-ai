@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Start-LocalAI.ps1" -OpenBrowser %*
if errorlevel 1 (
  echo.
  echo No se pudo iniciar. Revisa el mensaje anterior.
  pause
  exit /b 1
)
echo.
pause
