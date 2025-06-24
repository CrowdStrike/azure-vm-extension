@echo off
set ES_EXT_DIR=%~dp0
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ES_EXT_DIR%disable.ps1"
exit /b %ERRORLEVEL%
