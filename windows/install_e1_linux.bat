@echo off
chcp 65001 >nul
REM ============================================================
REM  搜狗 E1 : 一键安装 arm64 Linux (Ubuntu 22.04) 到设备
REM
REM  特点: 不刷机 / 不改分区 / 不重启设备 / 完全可逆
REM        原厂内核 (DRM 显示 + 8 麦阵列驱动) + Ubuntu 用户态
REM        通过 chroot 运行, 原厂系统照常工作
REM
REM  用法: 双击本文件 (设备需先连上 adb)
REM ============================================================
setlocal enabledelayedexpansion

set "ROOT=%~dp0.."
if not defined ADB set "ADB=adb"
if not defined E1_SERIAL (
  for /f "skip=1 tokens=1" %%i in ('"%ADB%" devices ^| findstr /R "device$"') do if not defined E1_SERIAL set "E1_SERIAL=%%i"
)
if not defined E1_SERIAL set "E1_SERIAL=CHANGEME"
set "SERIAL=%E1_SERIAL%"
set "DEVDIR=/mnt/sdcard"

where "%ADB%" >nul 2>&1
if errorlevel 1 (
  echo [X] 找不到 adb: %ADB%
  echo     请把 platform-tools 加入 PATH，或设置 ADB 变量指向 adb.exe
  pause & exit /b 1
)

echo.
echo ============================================================
echo   E1 arm64 Linux 安装器 (零风险 chroot 方案)
echo ============================================================
echo.

echo [0/5] 检查设备连接...
"%ADB%" start-server >nul 2>&1
"%ADB%" devices | findstr /C:"%SERIAL%" >nul
if errorlevel 1 (
  echo [X] 设备 %SERIAL% 未连接。请插 USB 或开启无线调试后重试。
  pause & exit /b 1
)
echo      设备在线 OK

echo.
echo [1/5] 检查/下载 Ubuntu base 22.04 arm64 rootfs...
set "UBTAR=%ROOT%\rootfs\ubuntu-base-22.04-arm64.tar.gz"
if not exist "%UBTAR%" (
  echo      本地没有，正在从清华镜像下载...
  if not exist "%ROOT%\rootfs" mkdir "%ROOT%\rootfs"
  curl -k -L -o "%UBTAR%" "https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cdimage/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.5-base-arm64.tar.gz"
)
if not exist "%UBTAR%" ( echo [X] rootfs 下载失败 & pause & exit /b 1 )
echo      OK: %UBTAR%

echo.
echo [2/5] 推送 rootfs 与安装脚本到设备...
"%ADB%" -s %SERIAL% push "%UBTAR%" %DEVDIR%/ubuntu-base.tar.gz
"%ADB%" -s %SERIAL% push "%ROOT%\scripts\setup_rootfs.sh" %DEVDIR%/setup_rootfs.sh
"%ADB%" -s %SERIAL% push "%ROOT%\scripts\enter_linux.sh" %DEVDIR%/enter_linux.sh
"%ADB%" -s %SERIAL% push "%ROOT%\scripts\setup_ubuntu_extra.sh" %DEVDIR%/setup_ubuntu_extra.sh
"%ADB%" -s %SERIAL% push "%ROOT%\scripts\run_e1recorder.sh" %DEVDIR%/run_e1recorder.sh

echo.
echo [3/5] 解包 Ubuntu (约 3500 文件)...
"%ADB%" -s %SERIAL% shell "sh %DEVDIR%/setup_rootfs.sh ubuntu"

echo.
echo [4/5] 配置 apt 源 / DNS / 原厂 ALSA 配置...
"%ADB%" -s %SERIAL% shell "sh %DEVDIR%/setup_ubuntu_extra.sh"

echo.
echo [5/5] 验证安装...
"%ADB%" -s %SERIAL% shell "sh %DEVDIR%/enter_linux.sh ubuntu 'cat /etc/os-release | head -3; uname -m; arecord -l | grep -i pdm'"

echo.
echo ============================================================
echo  安装完成!
echo.
echo  进入系统:
echo     adb -s %SERIAL% shell "sh %DEVDIR%/enter_linux.sh ubuntu"
echo.
echo  执行单条命令:
echo     adb -s %SERIAL% shell "sh %DEVDIR%/enter_linux.sh ubuntu 'uname -a'"
echo.
echo  录 8 麦 (3 秒):
echo     adb -s %SERIAL% shell "sh %DEVDIR%/enter_linux.sh ubuntu 'arecord -D 8c48kmic -f S32_LE -r 48000 -c 8 -d 3 /root/rec.wav'"
echo.
echo  卸载 (完全恢复原厂, 只需删目录):
echo     "%~dp0uninstall_e1_linux.bat"
echo ============================================================
echo.
pause
