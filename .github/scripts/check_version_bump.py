#!/usr/bin/env python3
"""检查 src/lib/base/version.ahk 中的版本号是否与已发布的 GitHub Release 版本重复。

用法（由 .github/workflows/version-check.yml 调用）：
    python3 check_version_bump.py \
        --version-file src/lib/base/version.ahk \
        --existing-versions existing_versions.txt

existing_versions.txt 每行一个版本 tag（GitHub Releases API 的 tag_name 与
仓库 tags API 的 name 并集，如 gh api repos/<repo>/releases --paginate
--jq '.[].tag_name' + gh api repos/<repo>/tags --paginate --jq '.[].name'）。

结果：
- 版本号与任一已发布 Release 重复 -> 退出码 1（CI 失败，提示先提升版本号）
- 无法读取/解析输入             -> 退出码 2（CI 失败，防止静默失效）
- 版本号是新的                  -> 退出码 0
"""
import argparse
import re
import sys

# 与 version.ahk 中 Ahk2Exe 指令同款匹配：static Number := "v2.0.0"
_VERSION_PATTERN = re.compile(r'^\s*static\s+Number\s*:=\s*"([^"]+)"\s*$', re.MULTILINE)


def normalize(version: str) -> str:
    """统一比较：去空白、小写、去掉 v 前缀（v2.0.0 与 2.0.0 视为同一版本）。"""
    v = version.strip().lower()
    if v.startswith("v") and len(v) > 1 and v[1].isdigit():
        v = v[1:]
    return v


def main() -> int:
    parser = argparse.ArgumentParser(
        description="检查当前版本号是否与已发布的 GitHub Release 版本重复"
    )
    parser.add_argument(
        "--version-file", required=True, help="含 Version.Number 定义的文件路径"
    )
    parser.add_argument(
        "--existing-versions", required=True, help="已有 Release tag 列表文件（每行一个）"
    )
    args = parser.parse_args()

    # 1. 读取当前版本号
    try:
        with open(args.version_file, encoding="utf-8") as f:
            content = f.read()
    except OSError as e:
        print(f"错误：无法读取版本文件 {args.version_file}：{e}", file=sys.stderr)
        return 2

    match = _VERSION_PATTERN.search(content)
    if not match:
        print(
            f"错误：无法从 {args.version_file} 中解析 Version.Number"
            "（应为 static Number := \"x.y.z\"）",
            file=sys.stderr,
        )
        return 2
    current = match.group(1).strip()
    if not current:
        print(f"错误：{args.version_file} 中 Version.Number 为空", file=sys.stderr)
        return 2

    # 2. 读取已有版本号
    try:
        with open(args.existing_versions, encoding="utf-8") as f:
            existing = [line.strip() for line in f if line.strip()]
    except OSError as e:
        print(f"错误：无法读取已有版本文件 {args.existing_versions}：{e}", file=sys.stderr)
        return 2

    # 3. 比较（按规范化后的小写去 v 版本号比较）
    current_norm = normalize(current)
    duplicates = sorted({tag for tag in existing if normalize(tag) == current_norm})

    if duplicates:
        tags = "、".join(duplicates)
        print(f"错误：当前版本号 {current} 已存在于已发布的 Release 中（tag: {tags}）。", file=sys.stderr)
        print(
            f"请先提升版本号（{args.version_file} 中的 Version.Number）再合并，"
            "避免发布重复版本。",
            file=sys.stderr,
        )
        return 1

    print(f"OK：版本号 {current} 未与任何已发布 Release 重复。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
