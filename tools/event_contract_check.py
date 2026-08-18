#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AFA 事件契约静态检查器。

检查 `src/**/*.ahk` 中的 EventBus.Publish / EventBus.Subscribe 调用，报告：

1. 有发布无订阅（孤儿发布者）；
2. 有订阅无发布（孤儿订阅者）；
3. 同一事件多个发布者（按“逻辑发布者”判定：同一模块/文件内的多个调用点
   视为同一发布者，允许收敛到单一发布函数）。

事件命名与 payload 契约以
`docs/adr/2026-08-17-event-contract-and-naming.md` 为基准；
本脚本负责代码侧的发布/订阅闭环与发布者唯一性校验。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"

_PUB_RE = re.compile(r'EventBus\.Publish\(\s*["\']([A-Za-z_][A-Za-z0-9_]*)["\']')
_SUB_RE = re.compile(r'EventBus\.Subscribe\(\s*["\']([A-Za-z_][A-Za-z0-9_]*)["\']')


def scan(src: Path) -> tuple[dict[str, set[str]], dict[str, set[str]]]:
    """返回 (publishers, subscribers)：事件名 -> 出现该调用的文件集合。"""
    publishers: dict[str, set[str]] = {}
    subscribers: dict[str, set[str]] = {}
    for f in sorted(src.rglob("*.ahk")):
        rel = f.as_posix()
        try:
            lines = f.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            print(f"warning: skip non-UTF8 file {rel}", file=sys.stderr)
            continue
        for line in lines:
            for m in _PUB_RE.finditer(line):
                publishers.setdefault(m.group(1), set()).add(rel)
            for m in _SUB_RE.finditer(line):
                subscribers.setdefault(m.group(1), set()).add(rel)
    return publishers, subscribers


def main(argv: list[str] | None = None) -> int:
    if not SRC.is_dir():
        print(f"error: source directory not found: {SRC}", file=sys.stderr)
        return 2

    publishers, subscribers = scan(SRC)
    problems: list[str] = []

    for event in sorted(publishers):
        if event not in subscribers:
            problems.append(
                f"[orphan-publisher] {event} 有发布无订阅："
                + ", ".join(sorted(publishers[event]))
            )

    for event in sorted(subscribers):
        if event not in publishers:
            problems.append(
                f"[orphan-subscriber] {event} 有订阅无发布："
                + ", ".join(sorted(subscribers[event]))
            )

    for event in sorted(publishers):
        if len(publishers[event]) > 1:
            problems.append(
                f"[multiple-publishers] {event} 多个发布者："
                + ", ".join(sorted(publishers[event]))
            )

    if problems:
        print(f"FAIL: event contract check found {len(problems)} problem(s)")
        for problem in problems:
            print("  " + problem)
        return 1

    print("PASS: event contract check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
