@echo off
REM LAN dual-launch — host on left, client on right
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

REM strip trailing backslash from %~dp0 to avoid cmd quoting issue
set "PROJDIR=%~dp0"
set "PROJDIR=%PROJDIR:~0,-1%"

echo Launching HOST instance (left) ...
start "Battle Tank - HOST" "%GODOT%" --path "%PROJDIR%" --position "80,60"
timeout /t 1 /nobreak >nul
echo Launching CLIENT instance (right) ...
start "Battle Tank - CLIENT" "%GODOT%" --path "%PROJDIR%" --position "720,60"

echo.
echo ----- LAN Test Steps -----
echo  1. HOST window:   click [Host], wait
echo  2. CLIENT window: click [Join], type 127.0.0.1, click [connect]
echo  3. HOST window:   click [Start Game]
echo  4. Both windows enter the arena simultaneously
echo --------------------------
endlocal
