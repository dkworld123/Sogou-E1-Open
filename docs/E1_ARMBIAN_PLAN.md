# 搜狗 E1 刷 Armbian — 作战方案与风险预案

> 最后更新：2026-11-12
> 设备：搜狗 AI 录音笔 E1（RK3308 / 约 492MB RAM / eMMC 29GB / Android 风格 A/B 双槽）
> 当前状态：原厂 Buildroot 固件，adb root 已开，已做完整救砖备份（MD5 校验通过）

---

## 0. 一句话结论

E1 的 **8 麦录音在现成固件上已经能直接录**（见 `scripts/export_recordings.py record`）。刷 Armbian 是为了把它变成通用 Linux 小电脑，
**有风险、是工程活、且本机无法编译**（需自备 Linux 构建机）。本方案采用**「保留原厂启动器、只换 boot_a+system_a」**的较低风险路线，
并依赖已完成的完整备份作为兜底。

---

## 1. 已核实的设备事实（刷机决策依据）

### 1.1 分区布局（来自 `/proc/partitions` + `/dev/block/by-name`）
| 分区 | 大小 | 作用 |
|---|---|---|
| p1 `uboot` | 2 MB | 原厂 U-Boot（启动器） |
| p2 `trust` | 2 MB | ARM Trusted Firmware（ATF，安全启动） |
| p3 `misc` | 1 MB | misc / 槽位标记 |
| p4 `boot_a` | 20 MB | 启动镜像 A（内核+DTB） |
| p5 `boot_b` | 20 MB | 启动镜像 B（=A，原厂后备） |
| p6 `system_a` | 400 MB | 根文件系统 A（squashfs，只读） |
| p7 `system_b` | 400 MB | 根文件系统 B（=A，原厂后备） |
| p8 `oem` | 64 MB | OEM 分区（可放开机自启脚本） |
| p9 `userdata` | 1 GB | 用户数据（录音库在此） |
| p10 `sdcard` | ~27 GB | 大容量用户存储 |
| `mmcblk0boot0/1` | 各 4 MB | eMMC 硬件 boot 分区（bootrom 首读） |

启动链：`eMMC boot0/1 → p1 uboot → p2 trust → p4 boot_a → p6 system_a`。
cmdline（来自 boot 镜像/chosen）：`root=PARTUUID=… skip_initramfs rootfstype=squashfs androidboot.slot_suffix=_a`。

### 1.2 原厂 `boot_a.img` 镜像格式（已解析）
- 标准 Android boot 镜像（`ANDROID!` magic），**page_size=2048**。
- 内核 4.61 MB，**LZ4 压缩**（magic `04 22 4d 18`）。
- **无 ramdisk**（ramdisk_size=0）；DTB（约 681 KB）放在镜像的 `second` 段。
- 根文件系统就是 `system_a` 的 **squashfs**，由内核 cmdline 直接挂载。

### 1.3 救砖备份（已完成，离线校验 OK）
位置：`backups/stock/*.img` + `md5.txt`（全部 MD5 校验通过）。
含：`uboot / trust / misc / boot_a / boot_b / system_a / system_b / oem / mmcblk0boot0 / mmcblk0boot1`。
设备上也有一份：`/mnt/sdcard/e1_backup/`（即使不开机，MaskROM 仍可读取该分区恢复）。

---

## 2. 刷机策略：保留启动器，只换 boot_a + system_a（较低风险）

**不使用** Armbian_E1 仓库 CI 里那个"猜的" `sakurapi-rk3308b_defconfig` 整机构建（U-Boot 不匹配极易变砖）。
改为：

- **不动** `uboot / trust / misc`（启动器完好 → 最坏情况用备份把 boot_a/system_a 写回即恢复，几乎不可能真变砖）。
- **替换** `boot_a`（Armbian 内核 + E1 DTB）和 `system_a`（Debian 根文件系统）。
- 保留 `boot_b / system_b` 作为原厂后备槽。
- 新内核的 cmdline 需从 squashfs 改为 **`rootfstype=ext4`**（新根文件系统不再是 squashfs）。

### 真变砖兜底（若有）
RK3308 进 **MaskROM**：短接 eMMC CLK↔GND 上电（或查 E1 具体进入方式），用 `rkdeveloptool` 把
`uboot/trust/boot_a/system_a` 备份写回 eMMC。因启动器备份齐全，**可 100% 复原原厂**。

---

## 3. 构建（必须在你的 Linux 主机上跑，本沙箱无法编译）

### 3.1 为什么不能在这儿编
本机是 Windows，且 WSL 被安全策略拉黑、Docker 未安装。Armbian 构建需要 Linux x86_64 + Docker。
→ 你需自备：**WSL2 Ubuntu 22.04 + Docker**，或一台独立 Linux x86_64 机器。

### 3.2 构建步骤（概览，`e1_build_armbian.sh` 为脚手架）
1. **内核**：基于 RK3308 主线/Armbian 内核，以仓库 `extracted.dts`（基于 `RK3308 evb`）为起点加 E1 节点；
   开启 RK3308 + PDM 麦克风阵列 + 音频Codec + 320×320 RGB LCD + 触摸(st1633i) + WiFi/BT 驱动；
   编译 arm64 `Image`，用 LZ4 压缩（`lz4` 或内核自带 `mkimage`/脚本）。
2. **根文件系统**：`debootstrap --arch=arm64 bookworm` 最小 Debian，装 `openssh-server alsa-utils vim` 等。
3. **打包 boot_a**：`mkbootimg --kernel Image.lz4 --second rk3308-e1.dtb --pagesize 2048 --cmdline "root=PARTUUID=<system_a的PARTUUID> rootfstype=ext4 rootwait" -o boot_a.img`。
4. **打包 system_a**：把 Debian rootfs 做成 ext4 镜像（`mkfs.ext4` + 复制 + `resize2fs`）。

### 3.3 内核的主要难点（诚实提示）
- RK3308 主线音频/PDM 支持一般，8 麦阵列需要 DTB 正确描述 + 可能的内核补丁。
- WiFi/BT 需要对应固件（博通/Realtek，看实机）；触摸屏 st1633i 需驱动。
- **约 492MB RAM**：只适合跑极简 Debian；Whisper 本地转写、Docker 等重负载不可行。

---

## 4. 刷入（`e1_flash.sh`，设备开机+adb root 状态下）
```bash
# 先把生成好的 boot_a.img / system_a.ext4.img 放到同目录，再：
bash e1_flash.sh            # 只打印将做什么，不执行
bash e1_flash.sh --yes      # 真正 dd 写入 boot_a + system_a 并重启
```
脚本会：校验备份存在 → 写 boot_a → 写 system_a → sync → reboot。
**注意**：首次务必先验证能 boot；若新内核起不来，立即用 `e1_recover.sh` 还原。

---

## 5. 回滚/救砖（`e1_recover.sh`）
```bash
bash e1_recover.sh --yes    # 用 e1_stock_backup 把 boot_a/system_a 写回原厂
```
若设备已无法 adb 启动，则用 MaskROM + `rkdeveloptool` 从备份写回（见第 2 节兜底）。

---

## 6. 风险清单
| 风险 | 可能性 | 后果 | 缓解 |
|---|---|---|---|
| 新内核不认某硬件（音频/屏/触控/WiFi） | 中 | 部分功能失效 | 系统能启动即可救；按需补 DTB/驱动 |
| boot_a 写入后无法启动且不能回退 | 低 | 需 MaskROM 救砖 | 备份齐全 + 保留 boot_b/system_b 后备 |
| 512MB RAM 限制 | 高 | 跑不了重负载 | 仅做轻量用途 |
| dd 过程中断电 | 低 | 分区损坏 | 写前确认供电稳定；备份可恢复 |

---

## 7. 下一步
1. 你在 Windows 上装 **WSL2 Ubuntu 22.04 + Docker**（或准备 Linux 机器）。
2. 在构建机上跑 `e1_build_armbian.sh`（按提示处理内核 DTB/驱动问题）。
3. 产物 `boot_a.img` + `system_a.ext4.img` 拷回本机，连上 E1，跑 `e1_flash.sh --yes`。
4. 起不来就 `e1_recover.sh --yes`，或 MaskROM 救砖。

> 提醒：刷机前请再次确认 `e1_stock_backup/` 已妥善保存（最好再复制到一块独立硬盘/U盘）。
