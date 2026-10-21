@echo off
rem Starts the Car Carnage: Belfast Edition game server (needs Node 18 or newer: https://nodejs.org).
cd /d "%~dp0"
where node >nul 2>nul || (echo Node.js is not installed. Get it from https://nodejs.org and run this again. & pause & exit /b 1)
node server.js %1
pause
