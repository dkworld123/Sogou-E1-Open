# 搜狗 E1：切换分区（A/B 槽）机制核实报告

> 核实日期：2026-11-13　设备：S/N `<SERIAL>`（root adb 在线）
> 结论先行：**切换分区不需要组合键，也不需要拆机。设备自带 Rockchip 官方 `updateEngine`，一条 adb 命令就能切，我这边可以直接操作。**
> 第一～八节的「机制核实」全过程**只读**。
> 2026-11-13 晚：**阶段 1 切槽回环验证**（第九节）与**阶段 2 把 Linux 装进 B 槽**（第十节）均已执行完成。
> 最终设备停在 **B 槽（Linux 版）**，A 槽仍是完整原厂，一条命令即可切回。
> 全程只写过 `system_b` 一个分区 + misc 元数据；`boot_a`/`boot_b`/`system_a`/`uboot`/`trust`/GPT 从未改动。

---

## 一、直接回答

| 你的问题 | 答案 |
|---|---|
| 切槽要组合键吗？ | **不要**。组合键在这台机上绑定的是「恢复出厂设置」，不是切槽。 |
| 你这边能操作吗？ | **能**。`adb shell /usr/bin/updateEngine --misc=other --reboot` 即可，纯软件、走 adb。 |
| 需要拆机 / MaskROM 吗？ | 正常切槽**不需要**。物理短接只是所有软件手段都失效后的最后兜底。 |
| GitHub / 其他方案？ | 只有 `Armbian_E1` 一个 WIP 仓库（无切槽工具）；但设备自带的**官方 SDK 机制**比任何第三方方案都稳，详见第五节。 |

---

## 二、真机实测证据

### 2.1 设备上就有官方切槽工具（此前漏查了驼峰命名）

```
-rwxr-xr-x root root 59480 Jan 14 2020  /usr/bin/updateEngine     # V1.0.1
-rwxr-xr-x root root   208 Jan 14 2020  /etc/init.d/S99_bootcontrol
```

`updateEngine --help` 原文：

```
--misc=now            Linux A/B mode: Setting the current partition to bootable
--misc=other          Linux A/B mode: Setting another partition to bootable
--misc=update         Recovery mode: Setting the partition to be upgraded
--misc=wipe_userdata  Format data partition
--update              Upgrade mode
--partition=0xFF00    Set the partition to be upgraded
--reboot              Restart the machine at the end of the program
```

`/etc/init.d/S99_bootcontrol` 内容：

```sh
start)  /usr/bin/updateEngine --misc=now ;;    # 每次开机自动「报平安」
```

→ 这构成完整闭环：`--misc=other` 切槽 → 开机 → `S99_bootcontrol` 自动 `--misc=now` 把新槽标记为成功启动。

### 2.2 uboot.img 明文含完整 A/B 状态机

`uboot.img`（2MB，头部 `LOADER  `，未压缩）里可直接读到：

```
lib/avb/libavb_ab/avb_ab_flow.c
ANDROID: Attempting slot %c, tries remaining %d
Mark slot %d active successfully.
avb_ab_mark_slot_active error!
Initialize ab data to misc partition success.
Slot A information:  slot A: priority = %d, tries_remaining = %d,
###There is no bootable slot, bring up lastboot!###
root=PARTUUID=$(ANDROID_SYSTEM_PARTUUID)
androidboot.slot_suffix=
rockchip_dnl_key_pressed / USB download gadget / rockusb 0 $devtype $devnum
bootonce-bootloader / boot-recovery / Enter bootrom download...
```

**最关键一条是 `root=PARTUUID=$(ANDROID_SYSTEM_PARTUUID)`**：uboot 会按选中槽**自动替换** `root=`，不用手工改 DTB / cmdline。

### 2.3 misc 分区里的 A/B 元数据，CRC 完全匹配

`misc + 0x800`，32 字节 Rockchip `AvbABData`：

| 字段 | 值 |
|---|---|
| magic / version | `\0AB0` / 1.0 |
| Slot A | priority=15, tries=3, successful=0 |
| Slot B | priority=14, tries=3, successful=0 |
| last_boot | 0（=A 槽） |
| CRC32（大端，前 28 字节） | `1AE58D3E`，与 `zlib.crc32` 计算值**完全一致** |

`misc + 0x1000`（BCB 命令区）当前全零，无挂起命令。

### 2.4 启动参数与分区 GUID 完全对得上

- 当前 `/proc/cmdline`：`root=PARTUUID=2F2F0000-0000-443D-8000-7EAA00005D21 ... androidboot.slot_suffix=_a rootfstype=squashfs`
- GPT：`system_a (p6)` GUID = `2F2F0000-…-7EAA00005D21`；`system_b (p7)` GUID = `A96B0000-0000-4122-8000-26000000272D`
- 即：**切到 B 槽后 uboot 会把 `root=` 换成 `A96B…272D` 并传 `slot_suffix=_b`**。

### 2.5 两个槽目前逐字节相同（安全性的关键）

备份 `backups/stock/md5.txt`：

```
34e91d778968aa57336efd3736843d72  boot_a.img
34e91d778968aa57336efd3736843d72  boot_b.img      ← 相同
38b7f94f8913b4fe606d3fc68bd1ec2b  system_a.img
38b7f94f8913b4fe606d3fc68bd1ec2b  system_b.img    ← 相同
```

→ **现在切到 B 槽，起来的就是一模一样的原厂系统**，A 槽完全不动。这让「切槽回环验证」成为近乎零风险的动作。

---

## 三、组合键到底是干嘛的（已读到原厂配置）

设备 `/etc/input-event-daemon.conf` 原文：

```ini
[Keys]
MUTE         = amixer -q set Master mute
FN+VOLUMEUP  = factory_reset_cfg
```

`/usr/sbin/factory_reset_cfg` 存在。Rockchip RK3308 SDK 文档也写明：`RECOVERY + VOLUMEUP` → `updateEngine --misc=wipe_userdata --reboot`（**恢复出厂设置 / 清 userdata**）。

所以：
- **组合键 ≠ 切槽**，它是恢复出厂；
- 物理按键 / 短接测试点在 uboot 里对应 `rockchip_dnl_key_pressed` → 进 **Loader / MaskROM 下载模式**，用于 PC 侧刷机救砖，不是日常切槽手段；
- 而且进 Loader 也能用软件：`adb reboot loader`（uboot 字符串里 `bootonce-bootloader`、`rockusb` 已证实支持，**尚未实跑**）。

---

## 四、通道与稳妥度排序

| 层级 | 通道 | 是否需物理操作 | 风险 | 当前状态 |
|---|---|---|---|---|
| 1 | **chroot Ubuntu 22.04 arm64 + Qt6 App**（现有成果） | 否 | **零**，删目录即还原 | ✅ 已跑通（8 麦录音 / Qt6 E1Recorder 编译并运行） |
| 2 | **`updateEngine --misc=other` 切 A/B 槽** | 否 | 低（A 槽不动、自动回滚） | ✅ 阶段 1 A→B→A 回环；✅ 阶段 2 B→A→B 双向回退实测，四次重启各约 20 秒上线 |
| 3 | **`adb reboot loader` + `rkdeveloptool`** 从 PC 重写任意分区 | 否（无需拆机） | 中 | uboot 字符串已证实；未实跑；需 PC 侧备好工具/驱动 |
| 4 | **拆机短接 eMMC 测试点 → MaskROM** | 是 | 高 | 仅作最后兜底 |

---

## 五、GitHub / 公开方案调研

| 来源 | 结论 |
|---|---|
| `Hermes-Language/Armbian_E1`（GitHub，已克隆到 `vendor/Armbian_E1/`） | 唯一 E1 专用仓库，仍是 **WIP 骨架**：`lib.config` 235B、`customize-image.sh` 0B；但 `extracted.dts` 97KB 完整、ALSA/UCM 配置齐全、`E1Recorder` 是 Qt6 App。**不含任何切槽/刷机工具**。 |
| `rockchip-linux/rkdeveloptool`（GitHub 官方） | 开源，PC 侧走 Rockusb 读写任意分区、救砖。是第 3 层通道的工具。 |
| Rockchip 官方《Linux updateEngine 升级指南》 | 正好是 **RK3308 Buildroot SDK**（文档引用 `buildroot/board/rockchip/rk3308/...`）。明确：`--misc=other` 切另一槽、`--misc=now` 报平安、`S99_bootcontrol` 开机执行；A/B 模式只升级 `boot_a/b` + `system_a/b`，**不支持升级 loader 和 parameter**。 |
| WhyCan 论坛《[废物利用] 搜狗E1录音笔重新开发》 | 楼主开 adb、`dd` 提取分区、IDA 逆 `SogouE1`。**反面案例**：有坛友「手贱刷了别的固件、自己写分区表刷入后卡 logo 重启」→ 印证**绝不能乱改 GPT / parameter**。 |
| 微信公众号《用 DeepSeek 花 10 元复活搜狗 E1》 | 完全不刷机的替代路线：DNS 劫持 + 自建服务端替代停服的搜狗云，设备上只加静态 uploader + crond。零固件风险，但目标不同（复活云服务，不是装 Linux）。 |

**判断**：设备自带的官方 `updateEngine` 就是最稳的方案，没有必要引入第三方切槽 hack 或自己手改 misc 的 CRC。

---

## 六、稳妥路线（建议按阶段走，每阶段都有回滚点）

### 阶段 0（历史起点）
chroot Ubuntu + Qt6 `E1Recorder`，零分区改动。现已成为阶段 2 B 槽开机脚本所复用的用户空间。

### 阶段 1：切槽回环验证（✅ 已于 2026-11-13 执行完成，详见第九节）
```bash
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/slot_tool.sh backup"      # 先备份 misc
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/slot_tool.sh switch --go"  # 切 B 并重启
# 重启后重新连 adb：
adb -s "$E1_SERIAL" shell cat /proc/cmdline   # 应出现 _b 与 A96B...272D
adb -s "$E1_SERIAL" shell "sh /mnt/sdcard/slot_tool.sh switch --go"  # 切回 A
```
为什么安全：B 与 A 逐字节相同；A 槽不动；`userdata`/`sdcard` 是共享分区，数据不丢；`S99_bootcontrol` 自动报平安；若启动失败，uboot 按 `tries_remaining`（当前 3）递减并自动回滚 `last_boot` 槽。

> ⚠️ 会重启设备、短暂断 adb、chroot 挂载需重新执行 `enter_linux.sh`（数据都在 sdcard，不丢）。
> 实测：两次重启各约 20 秒重新上线，sdcard 数据零丢失，`run_e1recorder.sh` 会自动重新挂载 chroot，无需人工干预。

### 阶段 2：把 Linux 装进 B 槽（✅ 已于 2026-11-13 执行完成，详见第十节）
用户确认采用「保留原厂 + 开机进 Ubuntu」形态。实际执行比原计划更保守：
1. **只写了 `system_b (p7)` 一个分区**；`boot_b` 根本不用改（DTB 的 `root=PARTUUID` 是占位符，uboot 自动替换，见第十节 10.1）。
2. `system_b` = 原厂 squashfs 重打包（101.1MB，格式参数逐项一致），**只新增 2 个文件**：`/etc/init.d/S98_e1linux` 钩子 + `/etc/e1_slot_b_marker` 标记。
3. 真正逻辑放在 userdata 的 `/mnt/sdcard/e1_boot_linux.sh`：开机自动挂载 chroot 环境并启动 Ubuntu 22.04 里的 Qt6 `E1Recorder`。**以后改行为不用重刷分区**。
4. 保留了原厂 `adbd`/WiFi/8 麦/DRM/`S99_bootcontrol` → adb 永远在线，随时可切回 A。
5. 实测 B→A→B 双向切换均成功；A 槽仍是完整原厂系统。

> 早期设想的「独立 Ubuntu 原生根」未采用：400MB 分区装不下 1.45GB 的 Ubuntu rootfs，且独立根没有 adbd 就失去回连与切回 A 的通道。

### 阶段 3（可选）
Qt6 **上屏**（DRM/KMS）、给 B 槽 Ubuntu 加 SSH/dropbear、把开机脚本从 `offscreen` 切到 `linuxfb`。**不建议动 GPT/parameter**（见第五节反面案例）。

---

## 七、回滚 / 救砖四层

1. **自动**：uboot `libavb_ab` 递减 tries + `###There is no bootable slot, bring up lastboot!###` 兜底。
2. **软件切回**：`updateEngine --misc=other --reboot`（或从 `misc.backup.img` 用 `slot_tool.sh restore --go` 整个恢复 misc）。
3. **PC 侧重写分区**：`adb reboot loader` → `rkdeveloptool`（官方开源）用 `backups/stock/` 的 922MB 全分区备份 + MD5 回写 `boot_a`/`system_a`/`misc`。
4. **拆机 MaskROM**：断电 → 短接 eMMC 测试点 → 上电 → RKDevTool。仅当 1–3 全部失效。

---

## 八、本次交付

| 文件 | 说明 |
|---|---|
| `scripts/slot_tool.sh` | 槽位工具：`status`(只读) / `backup` / `arm` / `switch` / `markok` / `restore` / `loader`。**所有写操作必须显式加 `--go`**，否则只打印 DRY-RUN。已实跑 `status`、`backup`、`switch --go` ×2、`restore --go` ×1，全部通过。 |
| `docs/E1_SLOT_SWITCH.md` | 本报告 |
| `vendor/Armbian_E1/` | `Armbian_E1` 仓库（WIP 骨架） |
| `backups/stock/` | 全分区备份 922MB + `md5.txt`（已确认 A/B 两槽镜像各自相同） |

机制核实阶段未执行重启 / 写 misc / 切槽 / 改分区；阶段 1 执行记录见第九节。**全程未刷任何镜像、未改 boot/system/uboot/trust/GPT。**

---

## 九、阶段 1 执行记录（2026-11-13 晚，用户确认后执行）

### 9.1 执行前双保险校验

| 项 | 结果 |
|---|---|
| 设备 | `<SERIAL>` 在线，`uid=0(root)`，`androidboot.slot_suffix=_a` |
| misc 四方一致 | 设备现场 / sdcard 备份 / PC 副本 / 11-12 全量备份 均为 `bd5a4023aaf2f51f2ad62d6359c29227` |
| A/B 镜像现场校验 | `boot_a=boot_b=34e91d77…`、`system_a=system_b=38b7f94f…`（与 11-12 `md5.txt` 逐项一致） |
| 分区节点 | `boot_a=p4 / boot_b=p5 / misc=p3 / system_a=p6 / system_b=p7` |
| 额外备份 | PC 侧另存 `scripts/misc.pre-stage1.img`（1MB） |

### 9.2 时间线与实测证据

| # | 动作 | 实测结果 |
|---|---|---|
| 1 | `sh /mnt/sdcard/slot_tool.sh switch --go` | `updateEngine V1.0.1` 正常输出，adb 按预期断开 |
| 2 | 等待重连 | **约 20 秒**重新上线 |
| 3 | 读 `/proc/cmdline` | `androidboot.slot_suffix=_b`、`root=PARTUUID=a96b0000-0000-4122-8000-26000000272d` — 与第 2.4 节预测**完全一致**（uboot 自动替换 root=） |
| 4 | B 槽完整性 | root 正常、内核 4.4.143、GPT 两槽 GUID 不变；四个分区 md5 全部未变；sdcard 2.8G/26.6G；`e1linux/{ubuntu,alpine}`、`E1Recorder`(204008 B) 全在 |
| 5 | B 槽功能 | `sh /mnt/sdcard/run_e1recorder.sh offscreen` → 进程存活、日志空（无报错），脚本自动重新挂载 chroot |
| 6 | B 槽 misc | 主 AvbABData：`A pri=14 tries=3` / `B pri=15 tries=3` / `last_boot=1` / CRC `0x4A4F6B86` 计算值=存储值 → 证实 `S99_bootcontrol` 自动报平安、切槽靠**交换 priority** 实现 |
| 7 | 再次 `switch --go` | 约 20 秒上线，cmdline 回到 `_a` + `2f2f0000-…-7eaa00005d21` |
| 8 | 回环复核 | 四分区 md5 全未变；主 AvbABData 完全复原（A15 / B14 / last_boot=0 / CRC `0x1AE58D3E`）；数据齐全 |
| 9 | 全分区比对 | 整个 misc md5 变成 `e6ff6eaa…`，逐字节比对仅 **13 字节**不同，全部落在 `0x820–0x8C7` |
| 10 | `restore --go` 收尾 | 从原始备份整分区覆盖 → md5 回到 `bd5a4023…`，拉回 PC **bit-for-bit 一致**；回滚通道第 2 层实测可用 |

### 9.3 新发现：misc 里有 3 份 A/B 元数据（阶段 2 重要）

- `0x800` **主份**：标准 `AvbABData`，CRC32 大端。`updateEngine` 主要改这里，切回 A 后完全复原。
- `0x888` / `0x8B0` **两份影子数据**：magic 同为 `\0AB0`，但 CRC 为小端字节序、字段布局略有差异。`updateEngine` 只更新其中的 `last_boot` + CRC，priority/tries 保持原样；因此 A→B→A 后残留 `last_boot=1`（CRC 仍自洽，无害）。
- `0x820–0x87F`：一串指针值，运行时被写回（本次有 3 字节变化），无启动语义。

> **结论：绝不要自己手改 misc 字节或只改主份 CRC**，一律用官方 `updateEngine`；回滚一律用 `restore --go` 整分区覆盖。这也是第 2 层回滚通道必须实测的原因。

### 9.4 最终状态（阶段 1 结束）

- 槽位 `_a`，`root=PARTUUID=2f2f0000-…-7eaa00005d21`，root adb 在线。
- **misc 与执行前 bit-for-bit 相同**（`bd5a4023…`），`0x1000` BCB 命令区全零。
- `boot_a/b`、`system_a/b` 与 11-12 备份逐字节一致，**没有刷任何镜像**。
- sdcard 数据、chroot Ubuntu、Qt6 `E1Recorder` 全部完好；设备重启过两次，chroot bind mount 已失效，下次直接用 `run_e1recorder.sh` 即可（脚本会重挂）。
- 设备侧临时镜像已清理，仅保留 `/mnt/sdcard/misc.backup.img` 作回滚备份。

### 9.5 对阶段 2 的意义

已证明：`updateEngine --misc=other --reboot` 可靠、约 20 秒可重连、B 槽能起完整原厂系统、切回 A 同样可靠、`restore` 可整分区回滚。阶段 2 因此只需把 Armbian 写进 `boot_b (p5)` + `system_b (p7)`，再用同一条命令切过去；失败可切回 A 或 restore misc，B 槽起不来时 uboot 的 tries 递减 + lastboot 兜底也会自动回 A。

> 以上是阶段 1 结束时的预判。阶段 2 实际**只写了 `system_b`**（`boot_b` 无需改），详见第十节。

**截至阶段 2 结束仍未实跑**：`loader` / Rockusb 模式、Qt6 上屏（DRM/KMS）。

### 9.6 本次新增产物

| 文件 | 说明 |
|---|---|
| `scripts/misc.pre-stage1.img` | PC 侧 misc 原始快照（1MB，阶段 2 前的最新回滚基准） |
| `.probe/ab_stage1_b.oct` / `ab_stage1_a.oct` | B 槽 / 回环后 AvbABData 原始字节快照 |
| `.probe/misc.stage1.after.img` / `misc.stage1.restored.img` | 回环后、复原后的 misc 整分区快照（用于逐字节对比） |
| `/mnt/sdcard/misc.backup.img` | 设备侧回滚备份（保留，md5 `bd5a4023…`） |

---

## 十、阶段 2 执行记录（2026-11-13 晚，用户选定方案后执行）

### 10.1 关键勘察结论：为什么最后只写了一个分区

| 勘察项 | 实测结果 | 推论 |
|---|---|---|
| `boot_a.img` 头 | `ANDROID!`，kernel 4833932 B（LZ4），**ramdisk_size=0**，second 697856 B，page_size 2048，header v0，**cmdline 为空** | 无 initramfs，内核直接挂 root |
| second 段 | Rockchip `RSCE` resource 格式，DTB 在 `+0x800` | — |
| DTB `chosen/bootargs` | `earlycon=… console=ttyFIQ0 root=PARTUUID=614e0000-0000 rootfstype=squashfs rootwait snd_aloop.index=7` | `614e0000-0000` 是**占位符**，uboot 按槽替换（阶段 1 实测 A=`2f2f…` / B=`a96b…`）；`rootfstype=squashfs` 固定；**无 `init=`** |
| 内核默认 init | 找 `/sbin/init` → 原厂是 busybox init → `/etc/inittab` → `rcS` 按序执行 `/etc/init.d/S??*` | 只要新 squashfs 保留这套就能原样启动 |
| 原厂 squashfs | `SQUASHFS 4:0` / gzip / 128KB / **101.11 MB** / 4591 inodes | 400MB 分区还剩 298.9MB |
| Ubuntu chroot rootfs | `/usr` 799M + `/var` 651M = **1.45 GB** | **装不进 400MB**，独立 Ubuntu 原生根必须大幅裁剪 |
| 原厂关键服务 | `S21mountall` 挂 sdcard、`S50usbdevice` 起 adbd、`S98_lunch_init` 起 SogouE1、`S99_bootcontrol` 报平安 | 保留这一套 = 保住 **adb 回连 + 切回 A 的通道** |
| 设备工具 | busybox / `mkfs.ext4` / `switch_root` / `pivot_root` / wget 有；`mksquashfs` 原本没有（已在 chroot 内 apt 装 4.5） | — |

→ **结论**：`boot_b` 完全不用写（它本来就与 `boot_a` 逐字节相同，uboot 自动替换 `root=`）；`system_b` 必须是 squashfs；独立 Linux 根在容量和回连两方面都不可行。

### 10.2 采用的方案（用户选定「保留原厂 + 开机进 Ubuntu」）

- `system_b` = 原厂 squashfs **重打包**，只新增 2 个文件：
  - `/etc/init.d/S98_e1linux`：开机钩子。`rcS` 会以 `$0 start` **同步**调用，所以脚本立刻把实际工作丢后台并返回。
  - `/etc/e1_slot_b_marker`：B 槽身份标记。
- 真正逻辑在 **userdata 上的 `/mnt/sdcard/e1_boot_linux.sh`**（以后改行为**不用重刷分区**）：
  1. 幂等挂载 `/dev /dev/pts /proc /sys /tmp /run /dev/shm` 到 Ubuntu rootfs
  2. 写 `resolv.conf`
  3. `chroot` 启动 Qt6 `E1Recorder`（默认 `offscreen`，`E1_TAKE_OVER_DISPLAY=1` 才试验性抢屏）
  4. 写 `/mnt/sdcard/e1_slot_b.status` 状态标记
- 原厂 `adbd`/WiFi/8 麦/DRM/显示/`S99_bootcontrol` **全部保留** → adb 永远在线。

> 取舍：PID 1 仍是原厂 busybox init，不是纯净发行版原生启动。这是为了保住 adbd、显示驱动与随时可回退性。

### 10.3 执行时间线

| # | 动作 | 结果 |
|---|---|---|
| 1 | 现场 dd 备份 `boot_b`/`system_b` → PC `backups/stage2/` | MD5 `34e91d77…` / `38b7f94f…`，与 11-12 全量备份一致 |
| 2 | chroot 内 `apt install squashfs-tools` | 4.5 装好 |
| 3 | 解包原厂 squashfs → 注入 2 文件 → `mksquashfs -comp gzip -b 131072` | 5001 → **5003** 条目，101 MB，补零到 400MB，MD5 `41adf6a7…` |
| 4 | 新旧 superblock 比对 | SQUASHFS 4:0 / gzip / 128KB / fragments 301 / ids 5 / xattr 0 **逐项一致**，inodes 4591→4593 正好 +2 |
| 5 | `sh -n` 检查 3 个脚本 + **在 A 槽手动试跑开机脚本** | 语法全过；chroot 挂载成功、E1Recorder 起来、日志空（无报错）、状态文件正确 |
| 6 | `dd` 写入 `system_b`（此时系统仍跑在 A 槽、misc 指向 A，最安全窗口） | 整分区 MD5 `41adf6a77747631b4ebe64241b9927fc` **精确匹配**；`boot_a`/`boot_b`/`system_a`/`misc` MD5 全未变 |
| 7 | `switch --go` 切 B | 约 20 秒上线，`_b` + `a96b0000-…-26000000272d`；标记、钩子、开机日志、`E1Recorder`(PID 671)、`adbd`、`SogouE1` 全部验证通过 |
| 8 | 再实测 **B→A→B** | 回 A 时是纯原厂（`/etc/e1_slot_b_marker` 不存在）、再回 B 又进 Linux 版，各约 20 秒 |

### 10.4 最终状态

| 项 | 值 |
|---|---|
| 当前槽 | **`_b`（Linux 版）**，`root=PARTUUID=a96b0000-…-26000000272d` |
| `system_b` | `41adf6a77747631b4ebe64241b9927fc`（改造版 squashfs） |
| `system_a` / `boot_a` / `boot_b` | `38b7f94f…` / `34e91d77…` / `34e91d77…` —— **与出厂完全一致** |
| `uboot` / `trust` / GPT | 从未改动 |
| 进程 | `adbd` + `SogouE1`（原厂） + `E1Recorder`（Ubuntu chroot，offscreen） |
| 回退 | 一条 `updateEngine --misc=other --reboot` 即可回纯原厂 A |

### 10.5 日常使用 / 回滚速查

```sh
S=<SERIAL>

# 切回原厂 A 槽（或再从 A 切回 Linux B，命令相同）
adb -s $S shell "/usr/bin/updateEngine --misc=other --reboot"

# 看 B 槽开机结果
adb -s $S shell "cat /mnt/sdcard/e1_slot_b.status; cat /mnt/sdcard/e1_boot_linux.log"

# 改开机行为（改 userdata 脚本即可，不用重刷 system_b）
adb -s $S pull /mnt/sdcard/e1_boot_linux.sh ./e1_boot_linux.sh
#   编辑后： adb -s $S push ./e1_boot_linux.sh /mnt/sdcard/e1_boot_linux.sh
#   开关： E1_START_RECORDER=0 / E1_TAKE_OVER_DISPLAY=1（抢屏，试验性）

# 把 system_b 还原成原厂镜像（设备端已存备份，无需从 PC 传 400MB）
adb -s $S shell "dd if=/mnt/sdcard/e1_build/system_b.orig.img of=/dev/block/by-name/system_b bs=1M; sync"

# 强制下次开机回 A（恢复阶段 1 前的 misc 原始快照）
adb -s $S shell "sh /mnt/sdcard/slot_tool.sh restore --go"
```

### 10.6 本次新增产物

| 文件 | 说明 |
|---|---|
| `stage2/S98_e1linux` | 进 squashfs 的开机钩子 |
| `stage2/e1_slot_b_marker` | 进 squashfs 的身份标记 |
| `stage2/e1_boot_linux.sh` | **userdata 开机主脚本**（可随时改） |
| `stage2/build_system_b.sh` | chroot 内解包/注入/重打包脚本 |
| `backups/stage2/{boot_b,system_b}.orig.img` | PC 侧 B 槽原始镜像（421MB，MD5 已校验） |
| `/mnt/sdcard/e1_build/*.orig.img` | 设备侧同份备份（可就地 dd 回滚） |
| `/mnt/sdcard/e1linux/ubuntu/e1_stage2/system_b.new.img` | 400MB 成品镜像（可重刷 B 槽） |
| `/mnt/sdcard/e1_slot_b.status`、`e1_boot_linux.log` | 每次开机的状态与日志 |

### 10.7 遗留 / 下一步

- **自研 Qt6 `E1Recorder` 仍未上屏**（默认 `offscreen`）。但阶段 3 已用两套第三方 App 实测打通两条上屏路径：freE1 用 LVGL 直接写 `/dev/fb0`；chopin 用 patched `libqlinuxfb.so` + `QT_QPA_FB_DRM=1` 走 DRM/KMS（`/dev/dri/card0`）。详见 `docs/E1_APPS_INSTALLED.md`。
- 未装 SSH/dropbear；若想直接 `ssh` 进 Ubuntu，可在 `e1_boot_linux.sh` 里加（无需重刷分区）。
- `loader` / Rockusb 救砖通道仍未实跑。
- 若日后要做**独立原生 Linux 根**，必须先解决 400MB 容量与 adbd 回连两个硬约束。

---

## 十一、阶段 4：A/B 槽各跑一套录音 App（2026-11-13）

**问题**：`userdata` 是 A/B **共享分区**，`/userdata/system/SogouE1`（原厂 OTA 槽位）对两个槽是同一个文件，所以不能「A 槽装一套、B 槽装另一套」各自放文件。

**解法**：A/B 两个 squashfs 的启动链完全相同（`inittab ::respawn:SogouLunchProbe.sh` → `SogouLunch.sh` → 存在则 `exec /userdata/system/SogouE1`），因此把生效 launcher 换成**按槽位分发的脚本**即可，一个分区都不用改：

| 文件（都在 `/userdata/system/`） | 作用 |
|---|---|
| `SogouE1` | 生效 launcher = 分发器副本 |
| `SogouE1.dispatch` | 读 `/proc/cmdline` 的 `androidboot.slot_suffix`（退回 `root=PARTUUID` 前缀）判槽 → `exec` 对应 launcher |
| `e1_slot_apps.conf` | `SLOT_A=chopin` / `SLOT_B=freE1`，可选 `freE1\|chopin\|factory` |
| `SogouE1.freE1` / `SogouE1.chopin` | 两套原始 launcher |

认不出槽位 / 配置缺失 / 目标不存在 → 一律 `exec /usr/bin/SogouE1`（原厂）。分发器另处理 chopin 的 `disabled` 标记与 DRM CMA（`drop_caches`）、freE1 的崩溃计数。日志 `/mnt/sdcard/e1_slot_dispatch.log`。

**实测**：两次重启各约 20 秒上线。
- A 槽：`_a` + `2f2f…5d21` → `slot=A app=chopin`，纯原厂 Buildroot（无 B 槽标记 / 无 `S98_e1linux`），`qmlscene` 打开 `/dev/dri/card0`、`recorderd` 打开 `/dev/snd/pcmC2D0c`，`E1_RECORDER_UI_READY`。
- B 槽：`_b` + `a96b…272d` → `slot=B app=freE1`，`device UI up`、`fb: flush …`。
- `system_a=38b7f94f…`、`system_b=41adf6a7…`、`boot_a=boot_b=34e91d77…` 全程未变。

**用法**：`sh stage3/e1_app_switch.sh slots [A方案] [B方案]` 启用分槽、`status` 只读看状态；单槽模式 `freE1|chopin|factory` 会覆盖分发器。想把 A 槽恢复纯原厂体验：`slots factory freE1`；两槽一起回原厂：`rm -f /userdata/system/SogouE1`。详见 `docs/E1_APPS_INSTALLED.md` 第 5 节。

**操作教训**：本次第一次切槽时设备 WiFi 省电掉线，`switch --go` 实际**没有发出**、只是重连回来仍在 B 槽。以后切槽务必先 `adb devices` 确认在线，再「探测在线 → 立刻下发」，重启后以 `cmdline` 的 `slot_suffix` 为准复核，不要只看 adb 是否重连。
