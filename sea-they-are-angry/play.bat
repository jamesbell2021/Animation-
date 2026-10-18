@echo off
rem Launch Sea They Are Angry. Always runs Godots import first (a few seconds), so new
rem scripts pulled from git are registered before the game starts.
rem Usage: play.bat C:\path\to\Godot_v4.3-stable_win64.exe
set "GODOT=%~1"
if "%GODOT%"=="" set "GODOT=Godot_v4.3-stable_win64.exe"
echo Importing the project...
"%GODOT%" --headless --editor --quit --path "%~dp0."
"%GODOT%" --path "%~dp0."
