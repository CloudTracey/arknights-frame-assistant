#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AFA 四层依赖静态检查工具。

目标分层：

    bootstrap (src/main.ahk)
       ↓
    ui      (src/lib/ui/)
       ↓
    core    (src/lib/core/<domain>/)
       ↓
    base    (src/lib/base/)

本工具在迁移期同时支持两种文件位置判定：
1. 已经按目标目录落位的文件：按路径中的 /base/、/core/、/ui/ 识别；
2. 尚未迁移的旧平铺文件：使用 LEGACY_LAYER 显式映射到目标层。

当前检测两类违规：
- cross：跨层向上引用（core -> ui、base -> core/ui 等）；
- state：对旧 `State.` 类的引用（阶段 4 将删除 State，本项用于跟踪收敛）。

用法：
    python tools/layer_check.py                     # 列出当前违规并失败（有违规时）
    python tools/layer_check.py --baseline KNOWN_VIOLATIONS   # CI：只禁止新增违规
    python tools/layer_check.py --update-baseline KNOWN_VIOLATIONS  # 重新生成基线
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# 迁移期旧平铺路径 -> 目标层。新目录落位后由路径自动判定，无需维护。
LEGACY_LAYER: dict[str, str] = {
    "src/main.ahk": "bootstrap",
    "src/lib/version.ahk": "base",
    "src/lib/eventbus.ahk": "base",
    "src/lib/logger.ahk": "base",
    "src/lib/message_box.ahk": "base",
    "src/lib/token_protector.ahk": "base",
    "src/lib/file_extractor.ahk": "base",
    "src/lib/touch_injection.ahk": "base",
    "src/lib/config.ahk": "base",
    "src/lib/game_keys.ahk": "core",
    "src/lib/hotkey_control.ahk": "core",
    "src/lib/hotkey_actions.ahk": "core",
    "src/lib/level_detector.ahk": "core",
    "src/lib/game_monitor.ahk": "core",
    "src/lib/game_launcher.ahk": "core",
    "src/lib/game_auto_start.ahk": "core",
    "src/lib/log_exporter.ahk": "core",
    "src/lib/settings/settings_manager.ahk": "core",
    "src/lib/settings/loader.ahk": "core",
    "src/lib/settings/saver.ahk": "core",
    "src/lib/settings/actions.ahk": "core",
    "src/lib/settings/hotkey_conflict_validator.ahk": "core",
}

LAYER_ORDER: dict[str, int] = {
    "base": 0,
    "core": 1,
    "ui": 2,
    "bootstrap": 3,
    "unknown": -1,
}

# AHK 关键字，避免把控制流误认为顶层函数定义。
_CONTROL_KEYWORDS = {
    "if", "else", "for", "while", "switch", "case", "default",
    "loop", "try", "catch", "finally", "until", "return",
}

_CLASS_RE = re.compile(r"^\s*class\s+([A-Za-z_]\w*)\s*\{?")
# 顶层函数定义：行首无缩进，且同一行以 ) { 或 ) => 结尾。
_TOP_FUNC_RE = re.compile(r"^([A-Za-z_]\w*)\s*\(")
_TOP_FUNC_END_RE = re.compile(r"\)\s*(\{|=>)")
_STATIC_METHOD_RE = re.compile(r"^\s*static\s+([A-Za-z_]\w*)\s*\(")
_CLASS_REF_RE = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\s*\.\s*([A-Za-z_][A-Za-z0-9_]*)")
_FUNC_CALL_RE = re.compile(r"\b([a-zA-Z_][a-zA-Z0-9_]*)\s*\(")
_SETTIMER_RE = re.compile(r"\bSetTimer\s+([A-Za-z_]\w*)")
_STATE_REF_RE = re.compile(r"\bState\.\s*([A-Za-z_]\w*)")


def strip_ahk_comment(line: str) -> str:
    """去掉 AHK 行注释（; 到行尾），保留字符串字面量中的分号。"""
    out: list[str] = []
    in_str = False
    quote: str | None = None
    i = 0
    while i < len(line):
        ch = line[i]
        if in_str:
            out.append(ch)
            # 粗略处理 AHK 转义；反引号转义符不闭合字符串。
            if ch == quote and (i == 0 or line[i - 1] != "`"):
                in_str = False
        else:
            if ch in ('"', "'"):
                in_str = True
                quote = ch
                out.append(ch)
            elif ch == ";":
                break
            else:
                out.append(ch)
        i += 1
    return "".join(out)


def layer_for(rel_path: str) -> str:
    """根据相对路径返回目标层。"""
    if rel_path == "src/main.ahk":
        return "bootstrap"
    if "/base/" in rel_path:
        return "base"
    if "/core/" in rel_path:
        return "core"
    if "/ui/" in rel_path:
        return "ui"
    return LEGACY_LAYER.get(rel_path, "unknown")


def discover_files(src: Path) -> list[Path]:
    return sorted(src.rglob("*.ahk"))


def build_symbols(files: list[Path]) -> tuple[dict[str, str], dict[str, str]]:
    """返回 (class -> file, top-level function -> file)。"""
    class_defs: dict[str, str] = {}
    func_defs: dict[str, str] = {}
    for f in files:
        rel = f.as_posix()
        current_class: str | None = None
        try:
            raw_lines = f.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            # 含非 UTF-8 的文件不应出现在 AHK 源码中；跳过并让调用方知道。
            print(f"warning: skip non-UTF8 file {rel}", file=sys.stderr)
            continue
        for raw in raw_lines:
            stripped = raw.strip()
            m = _CLASS_RE.match(stripped)
            if m:
                current_class = m.group(1)
                class_defs[current_class] = rel
                continue
            m = _TOP_FUNC_RE.match(raw)
            if m and current_class is None and m.group(1) not in _CONTROL_KEYWORDS:
                if _TOP_FUNC_END_RE.search(raw):
                    func_defs[m.group(1)] = rel
            # 静态方法目前只用于符号表扩展；本工具按类名解析目标，不单独使用。
            _ = _STATIC_METHOD_RE.match(raw)
            if stripped == "}":
                current_class = None
    return class_defs, func_defs


def scan_violations(
    files: list[Path], class_defs: dict[str, str], func_defs: dict[str, str]
) -> tuple[list[str], list[str]]:
    """返回 (cross 违规列表, state 引用列表)。每项为稳定字符串。"""
    cross: list[str] = []
    state: list[str] = []
    for f in files:
        rel = f.as_posix()
        src_layer = layer_for(rel)
        try:
            raw_lines = f.read_text(encoding="utf-8").splitlines()
        except UnicodeDecodeError:
            continue
        for lineno, raw in enumerate(raw_lines, start=1):
            code = strip_ahk_comment(raw)

            for m in _STATE_REF_RE.finditer(code):
                state.append(f"{rel}:{lineno} -> State.{m.group(1)}")

            for m in _CLASS_REF_RE.finditer(code):
                cls, member = m.group(1), m.group(2)
                if cls not in class_defs:
                    continue
                target_file = class_defs[cls]
                if target_file == rel:
                    continue
                target_layer = layer_for(target_file)
                if LAYER_ORDER[src_layer] < LAYER_ORDER[target_layer]:
                    cross.append(
                        f"{rel}:{lineno} -> {cls}.{member} ({target_layer})"
                    )

            for m in _FUNC_CALL_RE.finditer(code):
                name = m.group(1)
                if name not in func_defs:
                    continue
                target_file = func_defs[name]
                if target_file == rel:
                    continue
                target_layer = layer_for(target_file)
                if LAYER_ORDER[src_layer] < LAYER_ORDER[target_layer]:
                    cross.append(f"{rel}:{lineno} -> {name}() ({target_layer})")

            for m in _SETTIMER_RE.finditer(code):
                name = m.group(1)
                if name not in func_defs:
                    continue
                target_file = func_defs[name]
                if target_file == rel:
                    continue
                target_layer = layer_for(target_file)
                if LAYER_ORDER[src_layer] < LAYER_ORDER[target_layer]:
                    cross.append(
                        f"{rel}:{lineno} -> SetTimer {name} ({target_layer})"
                    )

    # 去重并排序，保证输出/基线稳定。
    return sorted(set(cross)), sorted(set(state))


def _violation_sort_key(v: str) -> tuple[str, str, int, str]:
    """按 [类别, 路径, 行号, 目标] 排序，保证基线可读且稳定。"""
    prefix, _, rest = v.partition("] ")
    path_line, _, target = rest.partition(" -> ")
    path, _, line = path_line.rpartition(":")
    try:
        line_num = int(line)
    except ValueError:
        line_num = 0
    return (prefix, path, line_num, target)


def format_violation(cross: list[str], state: list[str]) -> list[str]:
    items = [f"[cross] {v}" for v in cross] + [f"[state] {v}" for v in state]
    return sorted(items, key=_violation_sort_key)


def load_baseline(path: Path) -> set[str]:
    if not path.exists():
        return set()
    entries: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        entries.add(line)
    return entries


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", default="src", help="源码根目录（默认 src）")
    parser.add_argument(
        "--baseline",
        metavar="FILE",
        help="基线文件；CI 模式：只禁止新增违规，允许基线收敛",
    )
    parser.add_argument(
        "--update-baseline",
        metavar="FILE",
        help="把当前违规写入该文件并退出（用于重新生成基线）",
    )
    args = parser.parse_args(argv)

    src = Path(args.src)
    if not src.is_dir():
        print(f"error: source directory not found: {src}", file=sys.stderr)
        return 2

    files = discover_files(src)
    if not files:
        print(f"error: no .ahk files found under {src}", file=sys.stderr)
        return 2

    class_defs, func_defs = build_symbols(files)
    cross, state = scan_violations(files, class_defs, func_defs)
    current = format_violation(cross, state)

    if args.update_baseline:
        out = Path(args.update_baseline)
        out.parent.mkdir(parents=True, exist_ok=True)
        header = (
            "# AFA 耦合治理迁移基线（由 tools/layer_check.py --update-baseline 生成）\n"
            "# 每阶段只允许删除条目，不允许新增条目。\n"
        )
        out.write_text(header + "\n".join(current) + ("\n" if current else ""), encoding="utf-8")
        print(f"baseline written: {out} ({len(current)} entries)")
        return 0

    if args.baseline:
        baseline = load_baseline(Path(args.baseline))
        current_set = set(current)
        new_violations = sorted(current_set - baseline)
        resolved = sorted(baseline - current_set)
        if new_violations:
            print(f"FAIL: {len(new_violations)} new violation(s) not in baseline")
            for v in new_violations:
                print(f"  + {v}")
        if resolved:
            print(f"INFO: {len(resolved)} baseline violation(s) resolved")
            for v in resolved:
                print(f"  - {v}")
        if not new_violations:
            print(f"PASS: current violations are within baseline ({len(current_set)} current, {len(baseline)} baseline)")
            return 0
        print(f"Hint: if the change intentionally removes/re-locates violations, run --update-baseline {args.baseline}")
        return 1

    # 无基线：纯报告模式。
    if current:
        print(f"Found {len(current)} violation(s):")
        for v in current:
            print(f"  {v}")
        print("Use --baseline KNOWN_VIOLATIONS in CI, or --update-baseline to refresh.")
        return 1
    print("PASS: no violations found")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
