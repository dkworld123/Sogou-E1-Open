# 对上游源码的改动

上游项目（[`rossihwang/freE1`](https://github.com/rossihwang/freE1)、
[`chopinshown/sogouE1`](https://github.com/chopinshown/sogouE1)）**未声明 LICENSE**，
所以本仓库不分发它们的源码或修改后的文件本体，只在这里给出 diff 文本。
用 `sh tools/fetch_upstream.sh` 取到源码后，把下面的 diff 存成 `.patch` 自行应用。

> 下面所有 diff 都来自本机实测：`---` 是上游原版，`+++` 是本项目适配后的版本。

---

## 1. `chopinshown/sogouE1` → `recorder-app/run.sh`

三个目的：对齐原厂 Qt 环境、修正静态 alsa-lib 配置路径、避免 DRM CMA 分配失败。

```diff
--- a/recorder-app/run.sh
+++ b/recorder-app/run.sh
@@ -9,9 +9,16 @@
 export QT_QUICK_BACKEND=software
 export QT_QPA_EVDEV_KEYBOARD_PARAMETERS='/dev/input/event3:/dev/input/event1'
 export QT_QPA_EVDEV_TOUCHSCREEN_PARAMETERS='/dev/input/event0:rotate=0'
-export QT_QPA_FONTDIR=/usr/share/fonts
+export QT_QPA_FONTDIR=/data/fonts/
 export QT_QPA_PLATFORM_PLUGIN_PATH=/usr/lib/qt/plugins
 export QML2_IMPORT_PATH=/usr/qml
+export QT_LINUXFB_DRM_LOGO=/etc/sogou/boot.bmp
+# 静态编译的 alsa-lib 1.1.9 把 prefix 写死成 chroot 内路径，必须显式指向原厂配置，
+# 否则 snd_pcm_open("hw:2,0") 会报 "Unknown PCM"。
+export ALSA_CONFIG_PATH=/usr/share/alsa/alsa.conf
+# rockchip_gem_alloc_cma 需要连续物理内存；先回收页缓存，避免 200KB dumb buffer 分配失败
+sync
+echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
 BACKEND=
 UI=
 cleanup() {
```

依据：原厂 `/usr/bin/SogouLunch.sh` 用的是 `/data/fonts/`，并设置
`QT_QPA_FB_DRM=1` / `QT_LINUXFB_DRM_LOGO`。不照抄会首次
`Failed to create dumb buffer`（dmesg: `rockchip_gem_alloc_cma failed to allocate 204800 byte dma buffer`）。

## 2. `rossihwang/freE1` → `scripts/e1ui-launch.sh`

```diff
--- a/scripts/e1ui-launch.sh
+++ b/scripts/e1ui-launch.sh
@@ -13,6 +13,9 @@
 export HOME=/userdata
 export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/userdata/bin:/data/bin
 export LD_LIBRARY_PATH=/data/usrlibs:/usr/local/lib64:/data
+# 本机用全静态 alsa-lib 1.1.9 编译，其 prefix 被写死为 chroot 内路径；
+# 显式指向原厂 alsa.conf，保证进程内 ALSA 回放/监听能打开 hw:0,0 与 hw:2,0。
+export ALSA_CONFIG_PATH=/usr/share/alsa/alsa.conf
 
 # ---------- 2. 音频：原厂 RkLunch.sh + 录音所需的偏置/增益 ----------
```

## 3. `chopinshown/sogouE1` → `recorder-app/deploy.py`（以及若干脚本）

上游脚本把作者的 adb 序列号写死了，换成你自己的；更推荐改成读环境变量：

```diff
--- a/recorder-app/deploy.py
+++ b/recorder-app/deploy.py
@@ -7,7 +7,7 @@
 from pathlib import Path
 
 ROOT=Path(__file__).resolve().parent
-SERIAL="<UPSTREAM_SERIAL>"
+SERIAL=os.environ.get("E1_SERIAL", "<SERIAL>")
```

同样出现在 `host/capture_array.py`、`tests/*.py`、`firmware-analysis/backup_firmware.py`、
`hello-app/install-adb.py`、`test-noise-device.sh` 等，请全局搜索替换。

---

## 4. 本项目**独立新写**的文件（不是上游衍生品）

这些文件在 `stage3/`，可直接按 MIT 使用：

| 文件 | 作用 |
|---|---|
| `Makefile.e1local` | 把作者要求的 Bootlin gcc 6.4 交叉工具链换成**设备 chroot 原生 gcc + `-static`**；关键是 `LDLIBS := -lpthread -lasound -ldl -lm`（`-lm` 必须在 `-lasound` 之后） |
| `build_freE1_static.sh` | 在 chroot 内解包 alsa-lib 1.1.9 → 编静态 `libasound.a` → 装配 LVGL 9.2.2 → 编译 freE1 |
| `build_recorderd_static.sh` | `gcc -static` 编译 chopin 的 `recorderd.c wifi.c netaudio.c rtp_audio.c noise_reduce.c` |
| `SogouE1.dispatch` | 按 A/B 槽位分发到不同 App 的 launcher |
| `e1_slot_apps.conf` / `e1_app_switch.sh` | 分槽配置与切换脚本 |
| `deploy_freE1.sh` / `rollback_freE1.sh` | 部署与回滚 |

### 为什么改「全静态」

作者 README 要求 Bootlin `aarch64--glibc--stable-2018.02`（gcc 6.4 / glibc 2.26）交叉工具链，
但那是 **x86_64 host** 二进制，在这台 aarch64 设备上跑不了；chroot 里的 Ubuntu 22.04 是
glibc 2.35，动态编译会 `symbol not found`。用设备原生 gcc 11.4 全静态链接，把 libc 一起
打进二进制即可绕开原厂 glibc 2.26。产物：`freE1` 8,139,584 B、`recorderd` 4,307,256 B，
均 `statically linked`、无 `NEEDED`。

编译整轮在 RK3308 上约 11 分钟（`-j2`）。

---

## 5. 应用顺序

```sh
sh tools/fetch_upstream.sh                 # 上游源码到 vendor/
sh tools/fetch_deps.sh                     # LVGL / alsa-lib 到 deps/
# 手工应用上面 3 段 diff（或保存为 .patch 后 patch -p1 < file.patch）
# 把 stage3/ 下 3 个独立脚本放进构建目录
sh stage3/build_freE1_static.sh            # 在设备 chroot 内执行
sh stage3/build_recorderd_static.sh
```

更多踩坑与验证证据见 [`E1_APPS_INSTALLED.md`](E1_APPS_INSTALLED.md)。
