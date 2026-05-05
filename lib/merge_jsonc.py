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
    """Remove // and /* */ comments and trailing commas from JSONC text.

    String-aware: skips comment markers that appear inside JSON strings.
    Necessary because real settings.json files contain '//' inside URL
    string values like 'https://json-schema.org/'.
    """
    out = []
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c == '"':
            # Copy the whole string verbatim, honoring \" escapes.
            j = i + 1
            while j < n:
                if s[j] == "\\" and j + 1 < n:
                    j += 2
                    continue
                if s[j] == '"':
                    break
                j += 1
            out.append(s[i:j + 1])
            i = j + 1
            continue
        if c == "/" and i + 1 < n and s[i + 1] == "/":
            while i < n and s[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and s[i + 1] == "*":
            i += 2
            while i + 1 < n and not (s[i] == "*" and s[i + 1] == "/"):
                i += 1
            i = min(i + 2, n)
            continue
        out.append(c)
        i += 1
    result = "".join(out)
    # Trailing commas before } or ]. Theoretical false-positives inside
    # strings (e.g. ",  }" inside a string literal) but real settings.json
    # doesn't have them; leaving as a regex for simplicity.
    result = re.sub(r",(\s*[}\]])", r"\1", result)
    return result


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
        raw = f.read()
        text = strip_jsonc(raw).strip()
    if not text:
        return {}
    # strict=False lets raw control chars (tab, newline, etc.) appear inside
    # JSON strings. Spec-illegal but VS Code tolerates them, so settings.json
    # in the wild often has them — usually a literal newline pasted into a
    # 'workbench.colorCustomizations' block or similar.
    try:
        return json.loads(text, strict=False)
    except json.JSONDecodeError as e:
        # Re-raise with context lines around the failure, since the merge
        # caller swallows the exception's traceback location and a 'line N
        # col M' message alone isn't enough to find a typo in a 1000-line
        # settings.json.
        lines = raw.splitlines()
        lo = max(0, e.lineno - 3)
        hi = min(len(lines), e.lineno + 2)
        context = "\n".join(
            f"  {i+1:4d}{'>>' if i+1 == e.lineno else '  '} {lines[i]}"
            for i in range(lo, hi)
        )
        raise json.JSONDecodeError(
            f"{e.msg} in {path}\n--- context ---\n{context}\n--- /context ---",
            e.doc, e.pos
        ) from None


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
