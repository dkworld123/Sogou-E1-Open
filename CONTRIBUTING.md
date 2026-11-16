# 贡献约定

欢迎补坑、纠错、适配其它批次设备。

## 提交前请确认

1. **不要提交任何原厂固件 / 分区镜像 / 录音 / 数据库 / 密钥 / 本机绝对路径 / adb 序列号**。
   `.gitignore` 已挡住常见类型，但请自己再 `git status` 看一眼。
2. 所有设备序列号用 `$E1_SERIAL` / `<SERIAL>`，adb 路径用 `ADB` 环境变量或 PATH 里的 `adb`。
3. shell 脚本改动后跑 `sh -n <file>`；Python 改动后跑 `python -m py_compile <file>`。
4. 涉及写分区的脚本，**默认必须是只读预演**，真正的写操作要求显式参数
   （参考 `scripts/slot_tool.sh` 的 `--go` 约定）。
5. 上游项目的源码不要直接贴进本仓库。要说明改动，请写到
   `docs/UPSTREAM_PATCHES.md`（diff 文本）或提供下载脚本。
6. **设备端脚本必须保持 LF 换行**（`.gitattributes` 已锁定）。Windows 下若被转成 CRLF，
   `adb push` 后在 Linux 上执行会报 `^M: not found`；提交前用 `file <脚本>` 或
   `git diff --check` 确认。

## 文档约定

- 面向使用者的说明统一放在 `docs/`：`INSTALL.md`（怎么做）、`USAGE.md`（命令）、
  `FAQ.md`（排错）、`NOTICE.md`（注明事项）、`BACKLOG.md`（未完成）。
  新增文档请同步更新 `README.md` 的「目录结构」与「文档导航」。
- `docs/E1_*.md`、`SESSION_NOTES.md` 是开发期报告，技术数据（MD5、PARTUUID、时间戳）
  来自一台具体设备，引用时请注明是示例值，不要因为排版而改写原始结论。
- 新结论尽量附可复现的命令与输出，别只写「已验证」；未验证的事写进 `BACKLOG.md`。
- 目录路径以仓库根目录为基准，不要用本机绝对路径。
- 风险、免责、合规、隐私类内容统一写进 `docs/NOTICE.md`，不要散落到各文档里各说一套。

## 安全提醒

本项目会操作真实硬件分区。任何新方案请先说明**回滚路径**，
并保持「原厂 A 槽不动」这条底线。完整的注明事项见 [`docs/NOTICE.md`](docs/NOTICE.md)。
