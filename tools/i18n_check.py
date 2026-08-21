#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AFA i18n 静态检查。

扫描源码中的 I18n.T("...") 调用，与各语言资源表比对：
- 缺失：源码用到但 zh-Hans 资源没有
- 多余：资源中有但源码未使用
- 未使用：zh-Hans 有但源码未使用（仅提示）
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
LOCALES = SRC / "lib" / "base" / "locales"

_T_CALL_RE = re.compile(r'I18n\.T\(\s*["\']([A-Za-z0-9_.-]+)["\']')
_KEY_RE = re.compile(r'^\s*["\']([A-Za-z0-9_.-]+)["\']\s*,')


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
    problems: list[str] = []
    for key in sorted(used - zh):
        problems.append(f"[missing] {key} 在 zh-Hans 资源中缺失")
    for key in sorted(zh - used):
        print(f"INFO: [unused] {key} 在源码中未使用")
    for locale in ["zh_hans", "zh_hant", "ja_jp", "ko_kr", "en_us"]:
        res = extract_resource_keys(LOCALES / f"{locale}.ahk")
        for key in sorted(zh - res):
            problems.append(f"[missing-{locale}] {key} 在 {locale} 资源中缺失")
    if problems:
        print(f"FAIL: i18n check found {len(problems)} issue(s)")
        for p in problems:
            print("  " + p)
        return 1
    print("PASS: i18n check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
