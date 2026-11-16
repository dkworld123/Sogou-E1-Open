# 变更记录

本项目采用日期式版本记录。这里的「版本」只表示**文档与脚本整理状态**，
不代表设备固件版本，也不构成任何升级承诺。

---

## v0.1.1 — 2026-11-16

仓库工程化增强（不改任何设备侧逻辑）。

**新增**

- `.github/workflows/ci.yml`：push / PR 自动跑 CI——
  `sh -n` 全量 shell 语法检查（含无扩展名的 `S98_e1linux`、`SogouE1.dispatch`）、
  shellcheck（error 级）、`py_compile`、Markdown 相对链接断链检查、
  敏感串扫描、设备端脚本 CRLF 检查。
- `tools/check_links.py`：Markdown 相对链接检查，可本地复现 CI 结果。
- `tools/check_secrets.py`：敏感信息扫描（本机绝对路径、token 前缀、私钥、
  密钥赋值、内网 IP、IM 文件目录），脚本自身与 CI 配置自动排除。
- `tools/make_ecosystem.py` + `docs/images/ecosystem.svg`：四条路线的开源生态图，
  标注各上游项目的许可证状态；改数据后重跑脚本即可再生成。
- `.github/ISSUE_TEMPLATE/`：Bug 报告表单（设备批次 / 固件 / 槽位 / 操作层级 /
  复现步骤 / 日志）、功能建议表单、联系方式指引（指向 INSTALL / NOTICE / FAQ / BACKLOG）。
- `README.en.md`：完整英文版，与中文版内容对齐。

**变更**

- `README.md`：顶部徽章行（CI / MIT / 平台 / 刷机风险 / 文档语言）、
  中英文切换入口、新增「开源生态速览」章节、目录结构同步。
- 文档编号顺延：原「11. 声明、许可证与致谢」改为「12.」。

**验证**：CI 首次运行即通过（16 秒）；本地 103 条相对链接 0 断链、8 条敏感规则 0 命中。

---

## v0.1.0 — 2026-11-16

首次整理成可公开的开源仓库。

**新增**

- `README.md`：按开源仓库通行体例重写入口（前置条件、分级安装、文档导航、回滚、已知局限）。
- `docs/NOTICE.md`：集中列明风险免责、合法合规、隐私脱敏、兼容性、操作禁忌与未验证项。
- `docs/INSTALL.md`：L0–L3 四级安装步骤、前置条件、安装后验证清单与回滚速查。
- `docs/USAGE.md`：导出、chroot、切槽、App 切换、依赖获取、Windows 脚本的命令速查。
- `docs/FAQ.md`：19 个常见问题与排错（含「是不是 Armbian」「fb0 没变」「静态链接」等）。
- `docs/BACKLOG.md`：未完成事项、优先级、硬约束与已放弃方案。
- `CHANGELOG.md`、`CONTRIBUTING.md`、`THIRD_PARTY.md`、`LICENSE`、`.gitignore`。

**收录的既有成果**（2026-11-12 ~ 11-13 真机实测）

- 录音导出与 8 麦阵列直录（`scripts/export_recordings.py`）。
- 原厂内核 + Ubuntu 22.04 arm64 chroot，apt / gcc / Qt6 可用，零刷机。
- A/B 槽机制核实与可回退的 B 槽改造（`stage2/`、`scripts/slot_tool.sh`）。
- 两套开源录音 App 的全静态编译与按槽分发（`stage3/`）。
- 自写 Qt 5.9.4 录音器工程（`qt5-recorder/`）、ALSA 配置（`configs/`）。
- 开发期技术报告、调研清单与一张真机界面截图（`docs/`）。

**明确不包含**

- 原厂固件 / 分区镜像 / 录音 / 数据库 / 密钥 / 本机绝对路径 / 设备序列号。
- 未声明 LICENSE 的上游源码与任何编译产物；依赖统一由 `tools/fetch_*.sh` 获取。

---

## 更早（未纳入版本）

2026-11-12 ~ 11-13 为设备实机调试期，过程记录保留在
[`docs/SESSION_NOTES.md`](docs/SESSION_NOTES.md) 与各 `E1_*.md` 报告中，
路径与数值按当时状态保留，仅供追溯。
