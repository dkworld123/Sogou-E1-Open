#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
敏感信息扫描（CI 用）

检查仓库内是否混入了不该公开的东西：
  * 本机绝对路径（C:/Users/... 之类）
  * GitHub / 云厂商 token 前缀
  * SSH 私钥块
  * 明显的密钥赋值（password = xxx / api_key: xxx）
  * 内网 IP 与 IM 文件目录（微信等）

设计原则：
  * **宁可漏报也不误报**——文档里大量使用 <SERIAL> / <SSID> / 192.168.x.x 这类占位符
  * 脚本自身与 CI 配置默认排除（它们必然包含这些正则）
  * 命中只打印文件与行号，不打印密钥内容

用法：
    python3 tools/check_secrets.py
退出码：0 = 干净；1 = 发现疑似敏感内容
"""

import os
import re
import sys

SELF = os.path.basename(__file__)
DEFAULT_EXCLUDE = {SELF, 'ci.yml'}

RULES = [
    ('本机用户目录绝对路径',
     re.compile(r'[A-Za-z]:[\\/]+(?:Users|Documents\s+and\s+Settings|Program\s+Files|Windows|WorkBuddy)[\\/]')),
    ('GitHub token',
     re.compile(r'\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}')),
    ('GitHub fine-grained token',
     re.compile(r'\bgithub_pat_[A-Za-z0-9_]{20,}')),
    ('AWS access key',
     re.compile(r'\bAKIA[0-9A-Z]{16}\b')),
    ('私钥块',
     re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----')),
    ('密钥赋值',
     re.compile(r'(?i)\b(?:password|passwd|api[_-]?key|secret[_-]?key|access[_-]?token)\s*[=:]\s*[\'"]?[A-Za-z0-9\-_]{12,}')),
    ('内网 IP',
     re.compile(r'\b192\.168\.\d{1,3}\.\d{1,3}\b')),
    ('IM 文件目录',
     re.compile(r'(?i)xwechat_files|wechat files|微信文件')),
]

SKIP_DIRS = {'.git', 'node_modules', '__pycache__', '.probe', 'deps', 'vendor'}
TEXT_EXT = {'.md', '.sh', '.py', '.txt', '.yml', '.yaml', '.json', '.cfg', '.conf',
            '.pro', '.qml', '.qrc', '.bat', '.ps1', '.gitignore', '.gitattributes', ''}


def iter_text_files():
    for root, dirs, files in os.walk('.'):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if name in DEFAULT_EXCLUDE:
                continue
            ext = os.path.splitext(name)[1]
            if name.startswith('.') and ext == '':
                ext = ''          # .gitignore / .gitattributes
            elif ext not in TEXT_EXT:
                continue
            yield os.path.join(root, name).replace('\\', '/').lstrip('./')


def main():
    os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    hits = []
    for path in sorted(iter_text_files()):
        try:
            with open(path, encoding='utf-8') as fh:
                lines = fh.read().splitlines()
        except (OSError, UnicodeDecodeError):
            continue
        for no, line in enumerate(lines, 1):
            for label, rx in RULES:
                if rx.search(line):
                    hits.append((path, no, label))

    print('scanned repository files, %d rule(s) applied' % len(RULES))
    if hits:
        print('SUSPECT: %d hit(s)' % len(hits))
        for path, no, label in hits:
            print('  %s:%d  [%s]' % (path, no, label))
        print('\n请确认这些命中都是占位符/示例；若确属误报，请把规则或排除项加进本脚本。')
        return 1
    print('OK: no sensitive data found')
    return 0


if __name__ == '__main__':
    sys.exit(main())
