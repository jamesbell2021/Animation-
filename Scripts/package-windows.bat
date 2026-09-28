@echo off
rem Runs package-windows.ps1 without needing to change PowerShell's execution policy.
rem Any arguments are passed through, e.g.  package-windows.bat -Config Development
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0package-windows.ps1" %*
exit /b %ERRORLEVEL%
