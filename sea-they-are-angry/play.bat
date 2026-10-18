@echo off
rem Launch Sea They Are Angry. On a fresh clone, first runs Godots one-time import.
rem Usage: play.bat C:\path\to\Godot_v4.3-stable_win64.exe
set "GODOT=%~1"
if "%GODOT%"=="" set "GODOT=Godot_v4.3-stable_win64.exe"
if not exist "%~dp0.godot\global_script_class_cache.cfg" (
  echo First run: importing the project...
  "%GODOT%" --headless --editor --quit --path "%~dp0."
)
"%GODOT%" --path "%~dp0."
