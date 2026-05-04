#!/usr/bin/env python3
"""Deep-merge two JSONC files. Output: stdout.

VS Code / Cursor settings.json is JSONC (JSON with comments). Pure jq is
strict-JSON-only and chokes on // and /* */ comments. This helper strips
comments before parsing, deep-merges b into a (b's keys win on conflict),
and emits canonical JSON.

Usage:
    python3 merge_jsonc.py <existing.jsonc> <ours.jsonc>

Comments in the EXISTING file are stripped on merge — that's the documented
trade-off. Settings comments are rare and easily re-added if needed.
"""

import json
import re
import sys


def strip_jsonc(s: str) -> str:
    """Remove // and /* */ comments from JSONC text.

    Limitations: // or /* inside a JSON string value would be miscounted as
    a comment. Acceptable for settings.json which doesn't use // in strings.
    """
    s = re.sub(r"//.*?$", "", s, flags=re.MULTILINE)
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.DOTALL)
    # Strip trailing commas before } or ] (also legal in JSONC)
    s = re.sub(r",(\s*[}\]])", r"\1", s)
    return s


def deep_merge(a, b):
    """Merge b into a recursively. b wins on key conflicts.

    Lists are NOT merged (b replaces a). This matches user expectation for
    settings like keybindings where you want explicit control.
    """
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)
        for k, v in b.items():
            out[k] = deep_merge(a[k], v) if k in a else v
        return out
    return b


def load_jsonc(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        text = strip_jsonc(f.read()).strip()
    if not text:
        return {}
    return json.loads(text)


def main():
    if len(sys.argv) != 3:
        print("usage: merge_jsonc.py <existing> <ours>", file=sys.stderr)
        sys.exit(2)
    existing = load_jsonc(sys.argv[1])
    ours = load_jsonc(sys.argv[2])
    merged = deep_merge(existing, ours)
    print(json.dumps(merged, indent=2))


if __name__ == "__main__":
    main()
