@echo off
REM ============================================================
REM  E1 Qt5 Recorder - one-click build (inside WSL2) + deploy
REM  Run on Windows where WSL2 + Ubuntu 22.04 is installed.
REM  Pre-downloaded toolchain/Qt/alsa must be in the project dir.
REM  Usage:  build_and_deploy_e1.bat [--replace-factory]
REM ============================================================
setlocal enabledelayedexpansion

set "PROJ=%~dp0.."
set "APP=%PROJ%\e1_qt5_recorder"
if not defined WSLAPP set "WSLAPP=/mnt/c/path/to/repo/qt5-recorder"

echo.
echo [1/3] Checking WSL2 + Ubuntu...
where wsl.exe >nul 2>nul
if errorlevel 1 (
  echo ERROR: wsl.exe not found.
  echo   Install WSL2 first:  powershell -ExecutionPolicy Bypass -File "%PROJ%\install_wsl2_ubuntu.ps1"
  exit /b 1
)
wsl.exe --list --quiet | findstr /I "Ubuntu" >nul 2>nul
if errorlevel 1 (
  echo ERROR: no Ubuntu distro in WSL. Install it, then re-run.
  exit /b 1
)

echo.
echo [2/3] Installing host deps (if needed) + building Qt5 recorder inside WSL2...
echo       (first build takes 30-40 minutes; do not close the window)
wsl.exe bash -c "command -v gcc-9 >/dev/null 2>&1 && echo '[deps] gcc-9 present, skip install' || (cd %WSLAPP% && bash ../e1_build_env.sh)"
if errorlevel 1 (
  echo DEP INSTALL FAILED - ensure your WSL Ubuntu user has sudo. Fix and re-run.
  exit /b 1
)
wsl.exe bash -c "cd %WSLAPP% && bash build_e1_qt5.sh"
if errorlevel 1 (
  echo BUILD FAILED - see output above. Fix errors and re-run.
  exit /b 1
)
echo Build OK: %APP%\e1recorder

echo.
echo [3/3] Deploy to E1 (device must be connected via adb)...
if not exist "%APP%\e1recorder" (
  echo ERROR: %APP%\e1recorder missing - build may have failed.
  exit /b 1
)

REM Make adb reachable for the deploy script (Windows binary)
rem 请把 platform-tools 目录加入 PATH，或设置 ADB 环境变量

REM Locate Git Bash to run the deploy script
set "GITBASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "GITBASH=%ProgramFiles%\Git\bin\bash.exe"
if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" set "GITBASH=%ProgramFiles(x86)%\Git\bin\bash.exe"
if "%GITBASH%"=="" (
  echo WARNING: Git Bash not found. Skipping auto-deploy.
  echo   Manually run:  bash "%APP%\deploy_e1_qt5.sh"
  goto :done
)
"%GITBASH%" "%APP%\deploy_e1_qt5.sh" %*
echo.
echo Deploy launched. View log:  adb -s %E1_SERIAL% shell cat /tmp/e1rec.log

:done
echo.
echo All steps attempted. See above for results.
endlocal
