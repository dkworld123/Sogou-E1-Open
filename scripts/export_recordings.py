#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
E1 录音导出器 (Windows)  -  搜狗 AI 录音笔 E1 停服后自救工具
------------------------------------------------------------
纯读取、不改笔上任何文件。逻辑：
  1. 通过本地 adb 连上 E1（自动识别序列号 / 型号）
  2. 拉取 /userdata/databases/E1-DATA.db
  3. 解析 record_table，找出所有真实录音（路径以 /sdcard/ 开头）
  4. 把每条录音的 WAV（及同目录 _denoise.mp3 降噪版）导出到本机
     命名：<createTime 日期_时间>_<标题>.<ext>
  5. 用本地状态文件去重，已导出的不再重复拉取

用法：
  python3 e1_exporter.py            # 导出所有新录音到 ./e1_exports
  python3 e1_exporter.py --out D:/E1录音
  python3 e1_exporter.py --list     # 只列出笔上录音，不导出
  python3 e1_exporter.py --adb "C:/path/to/adb.exe"
  python3 e1_exporter.py record                 # 用 8 麦阵列录 10 秒并拉回
  python3 e1_exporter.py record --seconds 30    # 录 30 秒
  python3 e1_exporter.py record --out D:/E1录音

依赖：本机装有 Android Platform-Tools（adb.exe）。adb 不在 PATH 时，
      脚本会自动在 WorkBuddy 工作区里找，或用 --adb 指定。

说明：record 模式走设备原厂 asound.conf 里自带的 8c48kmic 命名 PCM，
      直接录取 8 麦阵列（8 通道 / 48kHz / S32_LE），纯读取、不改笔上系统。
"""

import os
import re
import sys
import json
import sqlite3
import subprocess

# ---------- 配置 ----------
KNOWN_ADB_DIRS = [d for d in os.environ.get("E1_ADB_DIRS", "").split(os.pathsep) if d]
E1_SERIAL_HINT = os.environ.get("E1_SERIAL", "")   # 为空时自动检测第一台设备
DB_REMOTE = "/userdata/databases/E1-DATA.db"
STATE_NAME = ".e1_exported.json"


def find_adb(cli_path=None):
    if cli_path:
        return cli_path
    env = os.environ.get("ADB_PATH")
    if env and os.path.exists(env):
        return env
    for d in KNOWN_ADB_DIRS:
        p = os.path.join(d, "adb.exe")
        if os.path.exists(p):
            return p
    # 末尾再试 PATH
    return "adb"


def run_adb(adb, serial, args, capture=True):
    cmd = [adb]
    if serial:
        cmd += ["-s", serial]
    cmd += args
    # MSYS 路径转换会破坏远程路径（如 /mnt/sdcard/...），强制关闭
    env = dict(os.environ)
    env["MSYS_NO_PATHCONV"] = "1"
    if capture:
        return subprocess.run(cmd, capture_output=True, text=True, env=env)
    return subprocess.run(cmd, env=env)


def detect_device(adb):
    r = run_adb(adb, None, ["devices"])
    lines = r.stdout.strip().splitlines()[1:]
    devices = [ln.split()[0] for ln in lines if ln.strip() and "device" in ln and "unauthorized" not in ln]
    if not devices:
        return None
    if E1_SERIAL_HINT in devices:
        return E1_SERIAL_HINT
    return devices[0]


def pull(adb, serial, remote, local):
    # 关键坑：MSYS 会把传给原生 adb 的非 ASCII 参数（中文文件名）改坏，
    # 导致拉错内容。所以让 adb 只经手 ASCII 临时名，拉完再用系统调用改名。
    local = local.replace("\\", "/")
    d = os.path.dirname(local)
    os.makedirs(d, exist_ok=True)
    import uuid
    tmp = os.path.join(d, "tmp_" + uuid.uuid4().hex + ".bin").replace("\\", "/")
    for attempt in range(2):
        r = run_adb(adb, serial, ["pull", remote, tmp])
        if r.returncode == 0 and os.path.exists(tmp):
            try:
                os.replace(tmp, local)
            except Exception as e:
                print("      [rename err]", e)
            return os.path.exists(local)
        if attempt == 0:
            import time
            time.sleep(1)
    if r.returncode != 0:
        print("      [adb err]", (r.stderr or r.stdout).strip()[:200])
    return False


def sanitize(name):
    name = re.sub(r'[\\/:*?"<>|]', "_", name or "未命名")
    return name.strip() or "未命名"


def norm_time(create_time):
    # '2019:10:01 00:00:55' -> '2019-10-01_00-00-55'
    if not create_time:
        return "unknown"
    s = create_time.replace(":", "-")
    s = s.replace(" ", "_")
    return s


def map_sdcard(path):
    # DB 里写 /sdcard/...，设备上对应 /mnt/sdcard/...
    if path and path.startswith("/sdcard/"):
        return "/mnt" + path
    return path


def record_on_device(adb, serial, seconds, remote_wav, pcm="8c48kmic", channels=8, rate=48000):
    # 在 E1 上用 arecord 从 8 麦阵列录音（仓库 asound.conf 自带 8c48kmic 命名 PCM），
    # 存到设备本地 /mnt/sdcard/...，纯读取、不改系统配置。
    d = remote_wav.rsplit("/", 1)[0]
    mk = run_adb(adb, serial, ["shell", 'mkdir -p "%s"' % d], capture=True)
    if mk.returncode != 0:
        print("    [warn] 建目录失败:", (mk.stderr or mk.stdout).strip()[:200])
    cmd = 'arecord -D %s -c %d -r %d -f S32_LE -d %d -t wav "%s"' % (
        pcm, channels, rate, seconds, remote_wav)
    print("[*] 设备端录音中(约 %.0f 秒): %s" % (seconds, cmd))
    r = run_adb(adb, serial, ["shell", cmd], capture=True)
    if r.returncode != 0 or (r.stderr and "error" in r.stderr.lower()):
        print("[!] arecord 失败/报错:")
        print("    stdout:", (r.stdout or "").strip()[:300])
        print("    stderr:", (r.stderr or "").strip()[:300])
        return False
    chk = run_adb(adb, serial, ["shell", 'ls -l "%s"' % remote_wav], capture=True)
    out = (chk.stdout or "") + (chk.stderr or "")
    print("    设备端:", out.strip())
    return "No such file" not in out and "No such" not in out


def main():
    args = sys.argv[1:]
    out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "e1_exports")
    cli_adb = None
    list_only = False
    record_mode = "record" in args
    seconds = 10
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--out":
            out_dir = args[i + 1]; i += 2
        elif a == "--adb":
            cli_adb = args[i + 1]; i += 2
        elif a == "--list":
            list_only = True; i += 1
        elif a == "--seconds":
            seconds = int(args[i + 1]); i += 2
        else:
            i += 1

    adb = find_adb(cli_adb)
    print("[*] adb:", adb)
    run_adb(adb, None, ["start-server"])

    serial = detect_device(adb)
    if not serial:
        print("[!] 没找到已连接的 E1。请确认：数据线连好、设备上 adb 已开、驱动正常（设备管理器出现 ADB Interface）。")
        sys.exit(1)
    print("[*] 已连接设备:", serial)

    # ---- 录制模式：直接在 E1 上录 8 麦阵列并拉回电脑 ----
    if record_mode:
        eight_dir = os.path.join(out_dir, "e1_8mic")
        os.makedirs(eight_dir, exist_ok=True)
        from datetime import datetime
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        remote = "/mnt/sdcard/e1_8mic/%s_8mic.wav" % stamp
        ok = record_on_device(adb, serial, seconds, remote)
        if ok:
            local = os.path.join(eight_dir, "%s_8mic.wav" % stamp)
            if pull(adb, serial, remote, local):
                print("[+] 已导出到:", local)
                try:
                    import wave as _w
                    w = _w.open(local, "rb")
                    print("    声道=%d 采样率=%d 时长=%.2fs 字节=%d" % (
                        w.getnchannels(), w.getframerate(),
                        w.getnframes() / w.getframerate(), os.path.getsize(local)))
                except Exception as e:
                    print("    [verify err]", e)
            else:
                print("[!] 拉取录音失败")
        else:
            print("[!] 录音失败")
        return

    # 拉取数据库
    local_db = os.path.join(out_dir, "E1-DATA.db")
    if not pull(adb, serial, DB_REMOTE, local_db):
        print("[!] 拉取 E1-DATA.db 失败")
        sys.exit(1)

    con = sqlite3.connect(local_db)
    cur = con.cursor()
    cur.execute("SELECT * FROM record_table")
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    con.close()

    # 列索引
    def idx(name):
        return cols.index(name) if name in cols else None
    i_title = idx("titleName")
    i_time = idx("createTime")
    i_type = idx("recordTypeName")

    state_path = os.path.join(out_dir, STATE_NAME)
    exported = set()
    if os.path.exists(state_path):
        try:
            exported = set(json.load(open(state_path, encoding="utf-8")))
        except Exception:
            exported = set()

    print("[*] 笔上共 %d 条录音记录" % len(rows))
    new_count = 0
    for row in rows:
        title = row[i_title] if i_title is not None else ""
        ctime = row[i_time] if i_time is not None else ""
        rtype = row[i_type] if i_type is not None else ""
        # 录音文件：从整行里挑出 /sdcard/ 下的 .wav（原始）和 _denoise.mp3（降噪），
        # 不依赖具体列名（不同固件版本里 playbackPath / waveFormPath 的分工会变）
        paths = [str(v) for v in row if isinstance(v, str) and v.startswith("/sdcard/")]
        wav_remote = next((map_sdcard(p) for p in paths if p.endswith(".wav")), None)
        mp3_remote = next((map_sdcard(p) for p in paths if p.endswith("_denoise.mp3")), None)
        if not wav_remote:
            continue  # 跳过系统自带样例（/etc/...）或无录音文件
        base = norm_time(ctime) + "_" + sanitize(title)
        wav_local = os.path.join(out_dir, base + ".wav")
        mp3_local = os.path.join(out_dir, base + "_denoise.mp3")

        status = "已导出" if base in exported else "新"
        print("  - [%s] %s | %s | %s" % (status, ctime, rtype, title))

        if list_only:
            continue
        if base in exported and os.path.exists(wav_local):
            continue
        ok_wav = pull(adb, serial, wav_remote, wav_local)
        ok_mp3 = False
        if mp3_remote:
            ok_mp3 = pull(adb, serial, mp3_remote, mp3_local)
        if ok_wav:
            exported.add(base)
            new_count += 1
            print("      -> 导出 WAV 成功" + ("；降噪MP3 成功" if ok_mp3 else "（无降噪版）"))
        else:
            print("      [!] WAV 导出失败:", wav_remote)

    if not list_only:
        json.dump(sorted(exported), open(state_path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        print("[+] 本次新增导出 %d 条，已导出总数 %d。存放于: %s" % (new_count, len(exported), out_dir))


if __name__ == "__main__":
    main()
