@echo off
rem Launch Connor Bell's Wonderland. Runs Godot's import first so the scripts load.
rem Usage: play.bat C:\path\to\Godot_v4.3-stable_win64.exe
set "GODOT=%~1"
if "%GODOT%"=="" set "GODOT=Godot_v4.3-stable_win64.exe"
echo Importing the project (a few seconds)...
"%GODOT%" --headless --path "%~dp0." --import
"%GODOT%" --path "%~dp0."
