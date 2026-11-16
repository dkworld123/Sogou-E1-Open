# Qt 5.9.4 录音器工程（本项目自写）

一个跑在搜狗 E1 **原厂 Qt 5.9.4 / glibc 2.26** 上的录音器：C++ 后端直接开 ALSA 采集，
QML 做 320×320 界面。这是本项目早期的路线；后来改走「设备本机 Ubuntu chroot + Qt6」，
但这份工程保留下来，作为**原厂 Qt 运行时**下最小可用 App 的参考。

> 需要真上屏时用原厂 `/usr/bin/SogouLunch.sh` 里的环境：
> `QT_QPA_FB_DRM=1` + patched `libqlinuxfb.so` 走 DRM/KMS；`/dev/fb0` 是假帧缓冲，
> 直接 linuxfb 写它未必能送到物理屏。详见 `../docs/E1_APPS_INSTALLED.md`。

## 文件

| 文件 | 说明 |
|---|---|
| `main.cpp` | 注册 `Recorder` 到 QML context，名字 `recorder` |
| `recorder.h` / `recorder.cpp` | ALSA 采集；属性 `recording/elapsed/level/status`，`Q_INVOKABLE start()/stop()` |
| `main.qml` / `demo_ui.qml` / `hello.qml` | 界面与最小冒烟页面 |
| `e1recorder.pro` | qmake 工程，支持 `LIBASOUND_LIBDIR` / `ALSA_INCLUDE`，静态 libstdc++ |
| `build_e1_qt5.sh` | 用 Bootlin 2018.02 工具链交叉编译 Qt 5.9.4 与本工程 |
| `deploy_e1_qt5.sh` | adb 部署 + 依赖自检 |
| `e1_run_qml.sh` | 设备端启动脚本（含原厂 Qt 环境变量） |

## 不随仓库分发的东西

- `libs/libasound.so*`（3 个约 900 KB 的 ALSA 动态库）是 LGPL 二进制且可从设备取得，
  已通过 `.gitignore` 排除。用 `adb pull /usr/lib/libasound.so.2.0.0` 从设备取，
  或用 `../tools/fetch_deps.sh` 下 alsa-lib 源码自行编译。
- Qt 5.9.4 源码、Bootlin 交叉工具链同样不入库，见 `../tools/fetch_deps.sh`。

## 已知坑（脚本里已固化）

1. Windows 解包 Bootlin 工具链的 symlink 会失败 → 在 WSL2 内解包。
2. Qt 5.9.4 的 host 工具用 GCC 11 编有风险 → `export CC=gcc-9 CXX=g++-9`。
3. 需 `-no-icu -qt-double-conversion`，否则运行时缺 ICU。
4. alsa-lib 源码头文件是扁平的 `include/*.h`，但代码用 `<alsa/asoundlib.h>`
   → 构建脚本会 staging 到 `alsa_inc/alsa/`。
5. 交叉工具链真实前缀是 `aarch64-buildroot-linux-gnu-`（不是 `aarch64-linux-gnu-`），
   脚本从 gcc 文件名自动推导。
6. 静态 libstdc++：`QMAKE_LFLAGS += -static-libstdc++`，避免原厂 glibc 2.26 兼容问题。

## 更推荐的路线

如果你只是想让这台设备跑自己的 Linux 程序，直接看
[`../docs/E1_LINUX_INSTALLED.md`](../docs/E1_LINUX_INSTALLED.md)：
在设备自带 Ubuntu 22.04 chroot 里用原生 gcc 编译，比交叉编译 Qt5 省事得多。
