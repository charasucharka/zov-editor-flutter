#!/usr/bin/env python3
"""Merge two localization files while keeping the base file's key order.

Use when you reorganize / add keys in one locale (base) while another contributor
updates translations (donor). The result keeps every key from the base file in
base order, but replaces values with donor translations where the donor has them.

Supports:
  - ARB files (app_en.arb, app_zh.arb, …) — message keys and @metadata keys
  - Flat resource JSON (resource_en.json, resource_zh.json, …)

Examples:
  py tools/merge_localization.py assets/l10n/app_zh.arb theirs/app_zh.arb -o assets/l10n/app_zh.arb
  py tools/merge_localization.py assets/l10n/resource_ru.json main/resource_ru.json --in-place
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


def load_json_object(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected a JSON object at the top level")
    return data


def detect_indent(text: str, default: int) -> int:
    for line in text.splitlines():
        match = re.match(r"^(\s+)\"", line)
        if match:
            return len(match.group(1))
    return default


def default_indent(path: Path) -> int:
    if path.suffix.lower() == ".arb":
        return 2
    if path.suffix.lower() == ".json":
        return 4
    return 2


def is_message_key(key: str) -> bool:
    return not key.startswith("@")


def merge_localization(
    base: dict[str, Any],
    donor: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, int]]:
    """Return merged dict (base order) and stats."""
    merged: dict[str, Any] = {}
    stats = {
        "message_updated": 0,
        "message_kept": 0,
        "metadata_updated": 0,
        "metadata_kept": 0,
        "donor_only_messages": 0,
    }

    base_messages = {k for k in base if is_message_key(k)}
    donor_messages = {k for k in donor if is_message_key(k)}
    stats["donor_only_messages"] = len(donor_messages - base_messages)

    for key in base:
        if key in donor:
            merged[key] = donor[key]
            if is_message_key(key):
                if base[key] != donor[key]:
                    stats["message_updated"] += 1
            elif base[key] != donor[key]:
                stats["metadata_updated"] += 1
        else:
            merged[key] = base[key]
            if is_message_key(key):
                stats["message_kept"] += 1
            else:
                stats["metadata_kept"] += 1

    return merged, stats


def write_json_object(path: Path, data: dict[str, Any], indent: int) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=indent)
        f.write("\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Merge localization files: keep key order from BASE, "
            "apply translated values from DONOR where present."
        ),
    )
    parser.add_argument(
        "base",
        type=Path,
        help="Primary file (more keys / desired order; values may be stale)",
    )
    parser.add_argument(
        "donor",
        type=Path,
        help="Secondary file (proper translations; may be missing new keys)",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Write result here (default: print to stdout unless --in-place)",
    )
    parser.add_argument(
        "--in-place",
        action="store_true",
        help="Overwrite BASE with the merged result",
    )
    parser.add_argument(
        "--indent",
        type=int,
        help="JSON indent spaces (default: detect from base file, else 2 for .arb / 4 for .json)",
    )
    parser.add_argument(
        "-q",
        "--quiet",
        action="store_true",
        help="Suppress summary on stderr",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if args.in_place and args.output is not None:
        print("error: use either --in-place or --output, not both", file=sys.stderr)
        return 2

    base_path = args.base.resolve()
    donor_path = args.donor.resolve()
    if not base_path.is_file():
        print(f"error: base file not found: {base_path}", file=sys.stderr)
        return 1
    if not donor_path.is_file():
        print(f"error: donor file not found: {donor_path}", file=sys.stderr)
        return 1

    base_text = base_path.read_text(encoding="utf-8")
    base = load_json_object(base_path)
    donor = load_json_object(donor_path)

    merged, stats = merge_localization(base, donor)

    indent = args.indent
    if indent is None:
        indent = detect_indent(base_text, default_indent(base_path))

    if args.in_place:
        out_path = base_path
    elif args.output is not None:
        out_path = args.output.resolve()
    else:
        payload = json.dumps(merged, ensure_ascii=False, indent=indent) + "\n"
        try:
            sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
            sys.stdout.write(payload)
        except (AttributeError, ValueError):
            sys.stdout.buffer.write(payload.encode("utf-8"))
        out_path = None

    if out_path is not None:
        write_json_object(out_path, merged, indent)

    if not args.quiet:
        base_msg_count = sum(1 for k in base if is_message_key(k))
        donor_msg_count = sum(1 for k in donor if is_message_key(k))
        print(f"Base:  {base_path} ({base_msg_count} message keys)", file=sys.stderr)
        print(f"Donor: {donor_path} ({donor_msg_count} message keys)", file=sys.stderr)
        print(
            f"Updated {stats['message_updated']} message(s), "
            f"kept {stats['message_kept']} from base (no donor match)",
            file=sys.stderr,
        )
        if stats["metadata_updated"] or stats["metadata_kept"]:
            print(
                f"Metadata: updated {stats['metadata_updated']}, "
                f"kept {stats['metadata_kept']} from base",
                file=sys.stderr,
            )
        if stats["donor_only_messages"]:
            print(
                f"Note: {stats['donor_only_messages']} message key(s) in donor "
                f"were not copied (absent from base)",
                file=sys.stderr,
            )
        if out_path is not None:
            print(f"Wrote {out_path}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
