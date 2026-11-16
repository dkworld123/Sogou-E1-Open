# 搜狗 E1 安装 Armbian — 实操指南（融合版）

> 整理时间：2026-11-13（基于 `Armbian_E1` 仓库实测 + 早期方案 + 回家手记）
> 设备：搜狗 AI 录音笔 E1（RK3308 / 约 492MB RAM / eMMC 无 SD 卡槽 / A-B 双槽 / Qt5.9.4 原厂系统）
> **本文件目的**：把"安装 Armbian"这件事的真相、两条路线、可执行步骤、坑位、救砖都讲清楚。

> **🔄 2026-11-13 晚间更新（以此为准）**：
> 1. 后来发现**设备自身就够用**，无需 WSL2/Docker/交叉工具链：已在 E1 上用 chroot 跑起 **Ubuntu 22.04.5 arm64 + Qt6 6.2.4**，并**在设备本机编译且运行了 Qt6 版 `E1Recorder`**，8 麦录音实录通过 → 见 `docs/E1_LINUX_INSTALLED.md`。
> 2. **A/B 切槽机制已完整核实**：设备自带官方 `/usr/bin/updateEngine`（`--misc=other` / `--misc=now`）+ `S99_bootcontrol`，uboot 含 `libavb_ab` 状态机，`misc+0x800` CRC 匹配 → **不需要组合键、不需要拆机，adb 一条命令即可切槽**；组合键其实是恢复出厂设置。详见 `docs/E1_SLOT_SWITCH.md`。
> 3. 因此本文第 0 节「必须用户自己的 WSL2+Docker 才能编译」已不再是唯一路径，保留作为 Armbian 正统构建路线的说明。
> 4. **✅ 阶段 2 已完成（以此为准）**：用户确认后，Linux 已真正装进 **B 槽** —— 设备默认从 B 槽启动，开机自动进入 userdata 上的 Ubuntu 22.04 + Qt6 `E1Recorder`；A 槽保持完整原厂，随时一条命令切回。实际只写了 `system_b` 一个分区（`boot_b` 无需改，uboot 自动替换 `root=PARTUUID`）。**执行记录、勘察数据、日常使用与回滚命令见 `docs/E1_SLOT_SWITCH.md` 第十节。** 本文第 0/4/9 节保留为"独立原生 Armbian 根"的历史方案说明，不再是当前路径。

---

## 0. 一句话结论（历史版本，见上方更新）

**沙箱（当前 WorkBuddy 环境）无法实际构建或刷入 Armbian**——它没有 Docker、没有 WSL2 权限、也无法接触物理设备。本文件能做的准备（克隆仓库、补完配置、写步骤）已全部完成，但**真正编译 + 烧写必须在你自己的 WSL2 + Docker 机器（或独立 Linux x86_64）上执行**。

Armbian_E1 仓库是**早期 WIP 骨架**：`lib.config` 原为空壳、`customize-image.sh` 是 0 字节、没有板级定义；但 `extracted.dts`（97KB 完整设备树）和 `overlay/` 里的 ALSA 配置（含 `rockchiprk3308v` UCM）已经相当完整，这是最大的有利条件。

---

## 1. 设备真相速查（已实测，避免再踩坑）

| 项 | 值 | 对 Armbian 的影响 |
|---|---|---|
| SoC | Rockchip RK3308（4×Cortex-A35, ARMv8） | 主线内核支持有限，需选合适分支 |
| 内存 | 约 492 MB | 只够极简 Debian；重负载（Docker/Whisper）不可行 |
| 存储 | **eMMC（mmcblk0），无 SD 卡槽** | **不能 SD 卡双启动试错**；刷机只能写 eMMC，失败=变砖 |
| 启动 | A/B 槽（`_a`/`_b`），根分区只读 squashfs | 早期方案只动 boot_a/system_a，保留启动器 |
| 显示 | `/dev/fb0` 是**假帧缓冲**（mmap 全 EINVAL）；真实走 **DRM/KMS `/dev/dri/card0`** | **最大坑**：Qt 自带 linuxfb 必崩；需 DRM 显示路径 |
| GPU | 全盘无 libEGL/libGLESv2/libMali | 纯软件渲染，别想 EGLFS/Mesa 硬件加速 |
| 系统 Qt | 5.9.4（部署型，无编译器） | 现成系统可直接跑 Qt5 App；Qt6 需 Armbian 另行安装 |
| 原厂 App | `/usr/bin/SogouE1`，override 入口 `/userdata/system/SogouE1` | 刷 Armbian 后不再存在 |

### 分区（by-name）
`uboot`(2M) / `trust`(2M) / `misc`(1M) / `boot_a`(20M) / `boot_b`(20M) / `system_a`(400M,squashfs) / `system_b`(400M) / `oem`(63M) / `userdata`(1G) / `sdcard`(~28G)
> 注意：`sdcard` 是 eMMC 内部大分区（用户存储），**不是物理 SD 卡槽**。设备板上没有 SD 卡座。

### 原厂 boot_a.img 格式（已解析）
- Android boot 镜像（`ANDROID!` magic），page_size=2048
- 内核 LZ4 压缩；**无 ramdisk**；DTB 在 `second` 段
- 根文件系统就是 system_a 的 squashfs，由 cmdline 直接挂载

---

## 2. Armbian_E1 仓库实测现状（本次已克隆到 `vendor/Armbian_E1/`）

| 路径 | 状态 | 说明 |
|---|---|---|
| `README.md` | 自述"完成 ALSA 导出 + 设备树提取" | 早期 WIP |
| `userpatches/lib.config` | **235 字节空壳** | 已在本工作区补完"待填项骨架"（见文件内注释） |
| `userpatches/customize-image.sh` | **0 字节（空）** | 需自己写（装包、改 fstab、加 E1 专属文件） |
| `userpatches/extracted.dts` | **97KB 完整** | 4.4 内核语法的完整 RK3308 EVB 设备树，**移植到主线 6.x 需适配** |
| `userpatches/overlay/` | 完整 ALSA 配置 | 含 `asound.conf` + `rockchiprk3308v` UCM，**音频部分已较齐** |
| `E1Recorder/` | **Qt6** 录音 App | 功能比我们的 Qt5 版更全（文件列表/设置页/硬件按键/Mock 层）；需 Armbian 装 Qt6 才能编译运行 |

**结论**：仓库给了"音频配置 + 设备树 + 一个 Qt6 目标 App"三块拼图，但**板级定义、内核选型、显示/触摸驱动、根 fs 定制全都还没做**。

---

## 3. 两条路线对比

### 路线 1：保留启动器，只换 boot_a + system_a（推荐，风险低）
- **不依赖** `armbian/build` 大框架（不强制 Docker，但内核交叉编译仍需 Linux 环境）。
- 用 RK3308 内核源码 + `extracted.dts` + `debootstrap` 根 fs + `mkbootimg` 打包 → 只 dd 写 `boot_a` + `system_a`，**不动 uboot/trust**（启动器完好 → 最坏用备份写回即恢复）。
- 脚手架已就绪：`e1_build_armbian.sh` + `e1_flash.sh` + `e1_recover.sh`。
- 优点：不动启动器、变砖概率极低（有 maskrom + 全分区备份兜底）、`extracted.dts` 现成。
- 难点：内核 + DTB + 驱动移植（尤其显示）。

### 路线 2：用官方 `armbian/build` 框架 + Armbian_E1 userpatches（"正统"，风险/成本更高）
- 克隆 `armbian/build`（1GB+，强依赖 **Docker** + ~30-40GB 空间）。
- 把 `vendor/Armbian_E1/userpatches/` 复制进去，并**补完板级定义**（`config/boards/rk3308-e1.conf`，RK3308 现成板极少，需仿 `rock-pi-s` 或新建）。
- 在框架内 `./compile.sh`。
- 缺点：框架对 RK3308 主线支持有限、需 Docker、编译数小时且 WIP 很可能失败/显示未打通。

> **建议**：先走路线 1 出可用镜像验证可行性；路线 2 是"更正规"但更重的备选。

---

## 4. 路线 1 详细步骤（在你自己的 WSL2 + Docker / Linux 机器上）

### 4.1 准备构建环境
```bash
# 需要：Linux x86_64（WSL2 Ubuntu 22.04 即可）+ aarch64 交叉工具链 + 设备树编译器
sudo apt-get update
sudo apt-get install -y build-essential git flex bison libssl-dev bc \
  device-tree-compiler u-boot-tools mkbootimg lz4 debootstrap \
  qemu-user-static gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```
> 交叉工具链用系统 `gcc-aarch64-linux-gnu`（基于你的宿主 glibc，足够编内核/根 fs）。Qt 录音 App 的 Qt 库直接复用 Armbian 根 fs 里装的 Qt（见 4.3）。

### 4.2 内核（最关键、最耗时）
```bash
git clone --depth 1 --branch <RK3308分支> https://github.com/armbian/linux-rockchip.git linux-rockchip
cd linux-rockchip
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig   # 借 rk3308 现有 defconfig
# 或 make ARCH=arm64 ... rockchip_defconfig
```
**必须做的适配**（按实机调试）：
1. 把 `extracted.dts`（4.4 语法）整理成主线 6.x DTB：节点路径、兼容字符串、bindings 要对照主线 `Documentation/devicetree/bindings`。
2. 开驱动：`CONFIG_SND_SOC_RK3308`（PDM 麦克风阵列）、音频 Codec、RGB/VOP 显示、面板（320×320，可能是 simple-panel 或私有 panel）、触摸 st1633i（主线若有）、SDIO/USB WiFi+BT（按实机芯片）、`CONFIG_KERNEL_LZ4=y`（内核 LZ4 压缩，与原厂 boot 一致）。
3. 编译：`make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs`
4. 编译 DTB：`dtc -I dts -O dtb ../vendor/Armbian_E1/userpatches/extracted.dts -o arch/arm64/boot/dts/rockchip/rk3308-e1.dtb`

**三大坑（诚实提示，未打通）**：
- **显示**：假 fb0，须走 DRM/KMS。主线 RK DRM 能否点亮这块 320×320 屏，取决于 DTB 里 VOP+面板节点是否正确 + 可能的内核补丁。Qt 显示后端只能选软件渲染（无 GPU）。建议先用 `kmscube`/`modetest` 验证 DRM 能否出图，再决定 Qt 走 `eglfs`（mesa llvmpipe 软渲）还是 port 工厂 patched `libqlinuxfb`。
- **触摸 st1633i**：确认主线是否有该驱动，没有就需移植。
- **WiFi/BT**：拆机确认芯片（博通/Realtek），放对应固件到 `/lib/firmware`。

### 4.3 根文件系统（Debian，含 Qt6 可选）
```bash
sudo rm -rf rootfs; mkdir -p rootfs
sudo debootstrap --arch=arm64 --foreign bookworm rootfs http://deb.debian.org/debian
sudo cp /usr/bin/qemu-aarch64-static rootfs/usr/bin/
sudo chroot rootfs /debootstrap/debootstrap --second-stage
sudo chroot rootfs apt-get install -y openssh-server alsa-utils alsa-ucm-conf \
     network-manager vim bluez i2c-tools
# 可选：装 Qt6（跑仓库里的 E1Recorder）
sudo chroot rootfs apt-get install -y qt6-base-dev qt6-declarative-dev qt6-multimedia-dev
# 把工厂 ALSA 配置带进去
sudo cp -a vendor/Armbian_E1/userpatches/overlay/etc/asound.conf rootfs/etc/
sudo cp -a vendor/Armbian_E1/userpatches/overlay/usr/share/alsa rootfs/usr/share/
```

### 4.4 打包镜像（LZ4 内核 + DTB 进 boot_a；ext4 进 system_a）
```bash
lz4 -f -9 linux-rockchip/arch/arm64/boot/Image Image.lz4
mkbootimg --kernel Image.lz4 --second rk3308-e1.dtb --pagesize 2048 \
  --cmdline "root=/dev/mmcblk0p6 rootfstype=ext4 rootwait console=ttyFIQ0,1500000" \
  --os_version 11.0.0 --os_patch_level 2020-01-01 -o boot_a.img
# system_a 做成 ext4
dd if=/dev/zero of=system_a.ext4.img bs=1M count=380
mkfs.ext4 -F -L e1root system_a.ext4.img
mkdir -p mnt; sudo mount -o loop system_a.ext4.img mnt
sudo cp -a rootfs/. mnt/; sudo umount mnt
```

### 4.5 刷入（保留启动器，较低风险）
```bash
# 把 boot_a.img / system_a.ext4.img 拷回 Windows，连上 E1：
bash e1_flash.sh --boot boot_a.img --system system_a.ext4.img --yes
# 预演（不写）先跑一次确认无误：bash e1_flash.sh --boot ... --system ...
```
刷前**务必确认 `backups/stock/` 备份在手**（见第 6 节）。

---

## 5. 路线 2 简要步骤（官方 armbian/build 框架）

```bash
# 需要 Docker（框架强依赖）
git clone --depth 1 https://github.com/armbian/build.git armbian_build
cp -r vendor/Armbian_E1/userpatches armbian_build/userpatches
cd armbian_build
# 在 config/boards/ 新建 rk3308-e1.conf（仿 rock-pi-s，填 BOARD/LINUXFAMILY/KERNEL_TARGET 等）
# 按 vendor/Armbian_E1/userpatches/lib.config 里的“补完建议”填内核分支与包列表
# 把 extracted.dts 编译为 rk3308-e1.dtb，让板级 conf 安装到 /boot/dtb/rockchip/
./compile.sh   # 选 rk3308-e1，Build 镜像
```
出镜像后**先别刷**：检查镜像内是否含 VOP/面板驱动、能否起串口、Qt6 是否可装。

---

## 6. 救砖流程（务必先备份再动）

- **正常回滚**（设备还能 adb 启动）：`bash e1_recover.sh --yes`（用 `e1_stock_backup` 写回 boot_a/system_a）。
- **变砖（无法启动）**：进 **MaskROM** —— E1 断电 → 拆机短接 eMMC CLK↔GND（或查 RK3308 具体进入点位）上电 → USB 连 PC。
  ```bash
  sudo rkdeveloptool db rk3308_loader.bin        # 进下载模式
  sudo rkdeveloptool wl 0x0   backups/stock/uboot.img     # 按分区偏移写回
  sudo rkdeveloptool wl <trust偏移> backups/stock/trust.img
  # …… 依此类推写回 boot_a/system_a；或整盘镜像还原
  sudo rkdeveloptool rd                          # 重启
  ```
- **救砖备份位置**：`backups/stock/*.img` + `md5.txt`（MD5 校验通过）。**这是唯一救砖筹码，动 eMMC 前必确认它在手，最好再复制一份到独立 U 盘/硬盘。**

---

## 7. 风险清单

| 风险 | 可能性 | 后果 | 缓解 |
|---|---|---|---|
| 新内核不认硬件（显示/触摸/音频/WiFi） | 高 | 部分功能失效 | 系统能启动即可救；逐驱动/DTB 调试 |
| 显示走不通（假 fb0 / DRM 未点亮） | 高 | 无 UI | 先用 kmscube/modetest 验证 DRM；port 工厂 patched libqlinuxfb |
| boot_a 写入后无法启动且不能回退 | 低 | 需 MaskROM 救砖 | 备份齐全 + 保留 boot_b/system_b 后备 |
| 无 SD 卡，刷机失败=变砖 | 中 | 拆机 maskrom | 备份 + 路线 1 保留启动器降低概率 |
| 492MB RAM 限制 | 高 | 重负载不可行 | 仅做轻量用途（录音器 / SSH 小工具） |
| dd 过程断电 | 低 | 分区损坏 | 写前确认供电；备份可恢复 |

---

## 8. 已准备好的资产（当前工作区）

| 资产 | 说明 |
|---|---|
| `vendor/Armbian_E1/` | 已克隆的 `Armbian_E1` 仓库（含 `userpatches/extracted.dts` 97KB、`overlay/` ALSA、`E1Recorder` Qt6 App）；`lib.config` 已补完待填骨架 |
| `e1_build_armbian.sh` | 路线 1 脚手架（kernel/rootfs/pack，含交互式 DTB 调整提示） |
| `e1_flash.sh` | 刷入 boot_a+system_a（保留启动器，含 `--yes` 实写 + 大小校验） |
| `e1_recover.sh` | 用备份写回原厂 |
| `backups/stock/` | 全分区救砖备份（uboot/trust/misc/boot_a/b/system_a/b/oem/boot0/1，MD5 通过） |
| `docs/E1_ARMBIAN_PLAN.md` | 早期"保留启动器"作战方案（可与本文互参） |

---

## 9. 最后建议

- **若只想有个能用的录音器**：现有 Qt5.9.4 的 `e1recorder`（已真机验证显示 + 8 麦录音）加个"返回/退出"按钮即可，**零风险**，不必折腾 Armbian。
- **若想要"纯净发行版原生启动"**：当前 B 槽方案是「原厂内核 + 原厂守护 + Ubuntu 用户空间」，已足够跑 Qt6 App 且可随时回退；要做独立原生根，必须先解决 **400MB 分区装不下 1.45GB Ubuntu rootfs** 与 **独立根没有 adbd 就失去回连/切回 A 通道** 两个硬约束（详见 `docs/E1_SLOT_SWITCH.md` 10.1）。
- **无论如何**：`e1_stock_backup/` 是底线，动 eMMC 前必确认它在手。

> 沙箱侧已完成：克隆仓库、核查真实状态、补完 `lib.config` 骨架、写本指南。编译与烧写请在本机 WSL2+Docker（或独立 Linux）执行；遇到具体报错把日志贴回，我据实精修。
