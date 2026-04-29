@echo off
REM Single instance launch
setlocal

set "GODOT="
where godot >nul 2>nul && set "GODOT=godot"
if "%GODOT%"=="" if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64.exe" set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.2-stable_win64.exe"
if "%GODOT%"=="" (
  echo [ERROR] Godot 4.6 not found. Install via:
  echo   winget install --id GodotEngine.GodotEngine --exact
  pause
  exit /b 1
)

set "PROJDIR=%~dp0"
set "PROJDIR=%PROJDIR:~0,-1%"
start "" "%GODOT%" --path "%PROJDIR%"
endlocal
