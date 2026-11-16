#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Markdown 相对链接断链检查（CI 用）

用法：
    python3 tools/check_links.py              # 检查仓库内所有 .md
    python3 tools/check_links.py docs README.md   # 只检查指定文件或目录

规则：
  * 只检查**相对路径**链接；http/https/mailto/tel/data/纯锚点一律跳过
  * 链接目标必须存在于仓库内（文件或目录都算，GitHub 会渲染目录页）
  * 代码块（``` 围栏）内的内容不参与检查，避免把示例里的路径误判为链接
退出码：0 = 无断链；1 = 存在断链
"""

import os
import re
import sys

LINK_RE = re.compile(r'\[[^\]]*\]\(\s*([^)\s]+)(?:\s+"[^"]*")?\s*\)')
SKIP_PREFIX = ('http://', 'https://', 'mailto:', 'tel:', 'data:', 'ftp://', '#')
SKIP_DIRS = {'.git', 'node_modules', '__pycache__', '.probe', 'deps', 'vendor'}


def iter_markdown(paths):
    """产出待检查的 .md 文件路径"""
    if not paths:
        paths = ['.']
    for p in paths:
        if os.path.isfile(p):
            if p.endswith('.md'):
                yield p
        elif os.path.isdir(p):
            for root, dirs, files in os.walk(p):
                dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
                for name in files:
                    if name.endswith('.md'):
                        yield os.path.join(root, name)


def main():
    # 始终以仓库根为基准，这样脚本从任何目录调用都一致
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)

    broken = []
    total = 0
    for md in sorted(iter_markdown(sys.argv[1:])):
        try:
            with open(md, encoding='utf-8') as fh:
                text = fh.read()
        except (OSError, UnicodeDecodeError) as exc:
            print('SKIP  %s (%s)' % (md, exc))
            continue
        # 去掉围栏代码块，避免示例命令里的路径被当成链接
        text = re.sub(r'```.*?```', '', text, flags=re.S)
        for raw in LINK_RE.findall(text):
            target = raw.strip()
            if not target or target.startswith(SKIP_PREFIX):
                continue
            path_part = target.split('#')[0].split('?')[0]
            if not path_part:
                continue
            total += 1
            resolved = os.path.normpath(os.path.join(os.path.dirname(md), path_part))
            if not os.path.exists(resolved):
                broken.append((md, target))

    print('checked %d relative link(s)' % total)
    if broken:
        print('BROKEN: %d' % len(broken))
        for src, tgt in broken:
            print('  %s -> %s' % (src, tgt))
        return 1
    print('OK: no broken relative links')
    return 0


if __name__ == '__main__':
    sys.exit(main())
