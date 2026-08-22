#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AFA i18n 静态检查（v2.0.1+，键 = 中文原文）。

扫描源码中的 I18n.T("...") 调用，与各语言资源表比对：
- 缺失：源码用到但任意语言资源都没有（残留旧点键，或新文案未同步翻译）
- 缺失语言：某键在 zh-Hant / ja-JP / ko-KR / en-US 资源中缺失（未翻译；非 zh-Hans 用户将
  回退显示中文原文并在运行时告警）
- 未使用：资源中有但源码未使用（仅提示；HotkeySchema.nameKey / Constants.*Names /
  DisplayNameKey 等经变量动态引用的键报 INFO 属预期）

注意：zh-Hans 资源表为空（键即原文），检查基准 = 四语言资源键集合的并集。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
LOCALES = SRC / "lib" / "base" / "locales"

# 键为中文原文（任意非引号字符，含 `n / {1} 转义原文）
_T_CALL_RE = re.compile(r'I18n\.T\(\s*["\']([^"\']+)["\']')
_KEY_RE = re.compile(r'^\s*["\']([^"\']+)["\']\s*,')

_LOCALES = ["zh_hant", "ja_jp", "ko_kr", "en_us"]


def extract_used_keys() -> set[str]:
    keys: set[str] = set()
    for f in SRC.rglob("*.ahk"):
        try:
            text = f.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for m in _T_CALL_RE.finditer(text):
            keys.add(m.group(1))
    return keys


def extract_resource_keys(path: Path) -> set[str]:
    keys: set[str] = set()
    if not path.exists():
        return keys
    for line in path.read_text(encoding="utf-8").splitlines():
        m = _KEY_RE.match(line)
        if m:
            keys.add(m.group(1))
    return keys


def main() -> int:
    used = extract_used_keys()
    zh = extract_resource_keys(LOCALES / "zh_hans.ahk")
    resources = {loc: extract_resource_keys(LOCALES / f"{loc}.ahk") for loc in _LOCALES}
    all_keys = set().union(*resources.values()) | zh

    problems: list[str] = []
    # 1) 任意语言资源都没有的键（残留旧点键或新文案未同步）
    for key in sorted(used - all_keys):
        problems.append(f"[missing] {key} 在任意语言资源中缺失（残留旧键或未同步翻译）")
    # 2) 语言间键集不一致（以键全集为准；zh-Hans 空表除外）
    for loc in _LOCALES:
        for key in sorted(all_keys - resources[loc]):
            problems.append(f"[missing-{loc}] {key} 在 {loc} 资源中缺失")
    # 3) 未使用提示（动态键属预期）
    for key in sorted(all_keys - used):
        print(f"INFO: [unused] {key} 在源码中未使用")
    if problems:
        print(f"FAIL: i18n check found {len(problems)} issue(s)")
        for p in problems:
            print("  " + p)
        return 1
    print("PASS: i18n check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
