#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 E1 开源生态图（docs/images/ecosystem.svg）

用法：
    python3 tools/make_ecosystem.py            # 输出到 docs/images/ecosystem.svg
    python3 tools/make_ecosystem.py out.svg    # 输出到指定路径

数据来源：docs/E1_GITHUB_PROJECTS.md（许可证状态查询于 2026-11-13）。
改完上面的清单记得同步改那张文档。
"""

import os
import sys

W, H = 980, 700

BG = '#ffffff'
BORDER = '#d0d7de'
TEXT = '#1f2328'
MUTED = '#59636e'

ROUTES = [
    {
        'title': '路线 A · 替换原厂 App（零刷机）',
        'desc': '只往 /userdata 写两个文件；删掉即回原厂，两个 App 互斥',
        'color': '#1f8833',
        'projects': [
            ('rossihwang/freE1', 'LVGL 9.2.2 录音 App', 'NO-LICENSE'),
            ('chopinshown/sogouE1', 'Qt Quick + 6 麦降噪', 'NO-LICENSE'),
        ],
        'note': '本项目采用：\nA 槽 = chopin（DRM/KMS 上屏）\nB 槽 = freE1（LVGL / fb0）\n按槽位分发，一个命令互换',
        'note_color': '#1f8833',
    },
    {
        'title': '路线 B · 补回停服的云转写',
        'desc': '不改固件，只写 /userdata；官方 2024-05-30 已停服',
        'color': '#0969da',
        'projects': [
            ('seabird000/E1Recorder', 'macOS 同步 + 自有云转写', 'MIT'),
            ('社区自建方案', '接管 *.sogou.com 私有协议', 'NO-LICENSE'),
        ],
        'note': '本项目尚未集成\n见 docs/BACKLOG.md',
        'note_color': '#59636e',
    },
    {
        'title': '路线 C · 研究资料（只读）',
        'desc': '显示 / 音频 / 按键 / 设备树，逆向结论的主要来源',
        'color': '#8250df',
        'projects': [
            ('Hermes-Language/E1_Research', 'DRM·8麦·触摸·按键', 'NO-LICENSE'),
            ('Hermes-Language/Armbian_E1', 'WIP：DTB + ALSA/UCM', 'NO-LICENSE'),
            ('Hermes-Language/build_e1', 'Armbian build framework', 'GPL-2.0'),
        ],
        'note': None,
        'note_color': None,
    },
    {
        'title': '路线 D · 同 SoC 底层参考',
        'desc': '换内核 / 换系统时才用；板级不同，只能当代码参考',
        'color': '#bc4c00',
        'projects': [
            ('jayanta525/rk3308-rock-pi-s', '同 SoC 的 OpenWrt 参考', 'NOASSERTION'),
            ('MitchRatquest/rk3308_synth', 'modern buildroot patch', 'NO-LICENSE'),
            ('JeffyCN/meta-rockchip', 'Rockchip Yocto BSP', '依仓库'),
        ],
        'note': None,
        'note_color': None,
    },
]

LICENSE_STYLE = {
    'MIT': ('#dafbe1', '#116329', '#1f8833'),
    'GPL-2.0': ('#ddf4ff', '#0a3069', '#0969da'),
    'NO-LICENSE': ('#fff8c5', '#633c01', '#9a6700'),
    'NOASSERTION': ('#f6f8fa', '#59636e', '#6e7781'),
    '依仓库': ('#f6f8fa', '#59636e', '#6e7781'),
}


def esc(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def card(x, y, w, h, name, desc, lic):
    bg, fg, border = LICENSE_STYLE.get(lic, ('#f6f8fa', '#59636e', '#6e7781'))
    out = []
    out.append(f'<g>')
    out.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="#f6f8fa" stroke="{BORDER}"/>')
    out.append(f'<rect x="{x}" y="{y}" width="4" height="{h}" rx="2" fill="{border}"/>')
    out.append(f'<text x="{x + 14}" y="{y + 22}" font-size="12.5" font-weight="600" fill="{TEXT}">{esc(name)}</text>')
    out.append(f'<text x="{x + 14}" y="{y + 39}" font-size="11" fill="{MUTED}">{esc(desc)}</text>')
    # 许可证角标
    badge_w = 8.0 * len(lic) + 12
    out.append(f'<rect x="{x + w - badge_w - 10}" y="{y + h - 25}" width="{badge_w}" height="16" rx="8" fill="{bg}" stroke="{border}"/>')
    out.append(f'<text x="{x + w - badge_w / 2 - 10}" y="{y + h - 13}" font-size="9.5" fill="{fg}" text-anchor="middle">{esc(lic)}</text>')
    out.append('</g>')
    return '\n'.join(out)


def note_box(x, y, w, h, text, color):
    lines = text.split('\n')
    out = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="#ffffff" stroke="{color}" stroke-dasharray="4 3"/>']
    for i, line in enumerate(lines):
        out.append(f'<text x="{x + 12}" y="{y + 20 + i * 17}" font-size="11" fill="{color}">{esc(line)}</text>')
    return '\n'.join(out)


def build():
    out = []
    out.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
               f'font-family="Segoe UI, Microsoft YaHei, Helvetica, Arial, sans-serif">')
    out.append(f'<rect width="{W}" height="{H}" fill="{BG}"/>')
    out.append(f'<rect x="0.5" y="0.5" width="{W - 1}" height="{H - 1}" rx="10" fill="none" stroke="{BORDER}"/>')

    out.append(f'<text x="28" y="42" font-size="21" font-weight="700" fill="{TEXT}">'
               f'搜狗 AI 录音笔 E1 · 开源生态图</text>')
    out.append(f'<text x="28" y="65" font-size="12" fill="{MUTED}">'
               f'Sogou AI Recorder E1 — open-source ecosystem map　|　四条互不相同的路线，'
               f'风险与收益差异很大</text>')

    y = 86
    for route in ROUTES:
        rows = len(route['projects'])
        h = 46 + rows * 74
        out.append(f'<rect x="20" y="{y}" width="6" height="{h}" rx="3" fill="{route["color"]}"/>')
        out.append(f'<text x="38" y="{y + 21}" font-size="14.5" font-weight="700" fill="{route["color"]}">'
                   f'{esc(route["title"])}</text>')
        out.append(f'<text x="38" y="{y + 39}" font-size="11.5" fill="{MUTED}">{esc(route["desc"])}</text>')

        cy = y + 52
        for name, desc, lic in route['projects']:
            out.append(card(38, cy, 430, 60, name, desc, lic))
            cy += 74

        if route.get('note'):
            out.append(note_box(492, y + 52, 468, 60 + (rows - 1) * 74, route['note'], route['note_color']))
        y += h + 18

    # 图例
    ly = y + 4
    out.append(f'<text x="28" y="{ly + 12}" font-size="12" font-weight="600" fill="{TEXT}">许可证标记：</text>')
    lx = 118
    for lic in ('MIT', 'GPL-2.0', 'NO-LICENSE', 'NOASSERTION'):
        bg, fg, border = LICENSE_STYLE[lic]
        bw = 8.0 * len(lic) + 14
        out.append(f'<rect x="{lx}" y="{ly}" width="{bw}" height="18" rx="9" fill="{bg}" stroke="{border}"/>')
        out.append(f'<text x="{lx + bw / 2}" y="{ly + 13}" font-size="10" fill="{fg}" text-anchor="middle">{esc(lic)}</text>')
        lx += bw + 10
    out.append(f'<text x="{lx + 6}" y="{ly + 13}" font-size="11" fill="{MUTED}">'
               f'NO-LICENSE = 上游未声明许可证（默认保留所有权利），本仓库只引用不打包</text>')

    out.append(f'<text x="28" y="{H - 20}" font-size="10.5" fill="{MUTED}">'
               f'数据来源：docs/E1_GITHUB_PROJECTS.md（许可证状态查询于 2026-11-13）　·　'
               f'生成脚本：tools/make_ecosystem.py</text>')
    out.append('</svg>')
    return '\n'.join(out)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.chdir(root)
    out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join('docs', 'images', 'ecosystem.svg')
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'w', encoding='utf-8') as fh:
        fh.write(build())
    print('wrote %s (%d bytes)' % (out_path, os.path.getsize(out_path)))


if __name__ == '__main__':
    main()
