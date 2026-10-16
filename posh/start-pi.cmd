@echo off
"%ProgramFiles%\PowerShell\7\pwsh.exe" -NoLogo -NoProfile -File "%~dp0start-pi.ps1" %*
exit /b %errorlevel%
