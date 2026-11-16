<#
.SYNOPSIS
  一键部署 WSL2 + Ubuntu 22.04（自动请求管理员权限）
.DESCRIPTION
  1) 自动以管理员身份重启本脚本（UAC 提权）
  2) 启用 "虚拟机平台" 与 "WSL" Windows 功能
  3) 将 WSL 默认版本设为 2
  4) 安装 Ubuntu 22.04 发行版
  用法：右键本文件 -> "使用 PowerShell 运行"
        或在管理员 PowerShell 中执行：  powershell -ExecutionPolicy Bypass -File install_wsl2_ubuntu.ps1
#>

# ---------- 1) 自提升为管理员 ----------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "需要管理员权限，正在请求 UAC 提权..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$ErrorActionPreference = "Stop"
function Step($m){ Write-Host "`n==== $m ====" -ForegroundColor Cyan }

# ---------- 2) 启用 Windows 功能 ----------
Step "启用 WSL / 虚拟机平台功能"
$needReboot = $false
foreach ($f in @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")) {
    $st = (Get-WindowsOptionalFeature -Online -FeatureName $f).State
    if ($st -ne "Enabled") {
        Write-Host "启用 $f ..." -ForegroundColor White
        dism /online /enable-feature /featurename:$f /all /norestart | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "启用 $f 失败，请检查日志。" }
        $needReboot = $true
    } else {
        Write-Host "$f 已启用，跳过。" -ForegroundColor DarkGray
    }
}
# 把 WSL2 设为默认
wsl --set-default-version 2 | Out-Null

if ($needReboot) {
    Write-Host "`n[!] 已启用虚拟化功能，WSL2 需要重启一次才能生效。" -ForegroundColor Yellow
    Write-Host "    请重启电脑后，再次右键运行本脚本 —— 它会跳过已启用的步骤，直接安装 Ubuntu。" -ForegroundColor Yellow
    exit
}

# ---------- 3) 安装 Ubuntu 22.04 ----------
Step "安装 Ubuntu 22.04"
$list = wsl --list --quiet
if ($list -match "Ubuntu-22.04|Ubuntu") {
    Write-Host "已检测到 Ubuntu 发行版，跳过安装。" -ForegroundColor DarkGray
} else {
    Write-Host "下载并安装 Ubuntu 22.04（需联网，约数百 MB，请耐心等待）..." -ForegroundColor White
    wsl --install -d Ubuntu-22.04
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] wsl --install 失败。可手动：开始菜单 -> Microsoft Store 搜索 Ubuntu 22.04 LTS 安装，或重跑本脚本。" -ForegroundColor Red
        exit 1
    }
}

Step "完成"
Write-Host "WSL2 + Ubuntu 22.04 已就绪。" -ForegroundColor Green
Write-Host "下一步：" -ForegroundColor White
Write-Host "  1) 从开始菜单打开 'Ubuntu 22.04'，按提示创建用户名/密码（只需一次）。" -ForegroundColor White
Write-Host "  2) 在该 Ubuntu 终端里执行： bash <REPO>/e1_build_env.sh   （安装构建依赖）" -ForegroundColor White
