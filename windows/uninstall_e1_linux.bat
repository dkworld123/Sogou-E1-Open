@echo off
chcp 65001 >nul
REM ============================================================
REM  卸载 E1 上的 arm64 Linux —— 完全恢复原厂状态
REM  因为全程只是 chroot，从未写入任何分区，只需卸载挂载并删目录
REM ============================================================
setlocal
if not defined ADB set "ADB=adb"
if not defined E1_SERIAL (
  for /f "skip=1 tokens=1" %%i in ('"%ADB%" devices ^| findstr /R "device$"') do if not defined E1_SERIAL set "E1_SERIAL=%%i"
)
if not defined E1_SERIAL set "E1_SERIAL=CHANGEME"
set "SERIAL=%E1_SERIAL%"
set "ROOT=/mnt/sdcard/e1linux"

echo.
echo ============================================================
echo   卸载 E1 arm64 Linux（原厂系统不会被改动）
echo ============================================================
echo.
echo   即将删除: %ROOT%
echo   以及     : /mnt/sdcard/*.tar.gz (rootfs 压缩包)
echo   设备分区、boot、system 均不受影响。
echo.
set /p CONFIRM="确认卸载? 输入 Y 继续: "
if /I not "%CONFIRM%"=="Y" ( echo 已取消 & pause & exit /b 0 )

echo.
echo [1/2] 卸载 chroot 挂载点...
for %%D in (dev/pts dev proc sys tmp mnt/host/usrlib mnt/host/usrqml) do (
  "%ADB%" -s %SERIAL% shell "umount %ROOT%/%%D 2>/dev/null" >nul 2>&1
)
echo      完成

echo [2/2] 删除目录与压缩包...
"%ADB%" -s %SERIAL% shell "rm -rf %ROOT% /mnt/sdcard/ubuntu-base.tar.gz /mnt/sdcard/alpine-minirootfs.tar.gz /mnt/sdcard/setup_rootfs.sh /mnt/sdcard/enter_linux.sh /mnt/sdcard/setup_ubuntu_extra.sh /mnt/sdcard/run_e1recorder.sh"
"%ADB%" -s %SERIAL% shell "echo '--- 确认已清空 ---'; ls -ld %ROOT% 2>/dev/null || echo '目录已删除'; df -h /mnt/sdcard | tail -1"

echo.
echo 卸载完成，设备已回到原厂状态（无需重启）。
pause
