#!/usr/bin/env python3
"""Check that every localized string literal in Swift sources resolves to a
key in Localizable.xcstrings with a translation for every language.

Exit code 0 = every key covered in every language. Exit code 1 = gaps.
"""

import json
import re
import sys
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STRINGS = os.path.join(ROOT, "Pearcleaner", "Resources", "Localizable.xcstrings")

def load_languages(catalog):
    langs = set()
    for entry in catalog["strings"].values():
        langs.update(entry.get("localizations", {}).keys())
    return langs

def swift_files(scope):
    if scope == "spacelens":
        pattern = "SpaceLens"
        base = os.path.join(ROOT, "Pearcleaner")
        for dirpath, _, names in os.walk(base):
            for name in names:
                if name.endswith(".swift") and pattern in name:
                    yield os.path.join(dirpath, name)
    else:
        base = os.path.join(ROOT, "Pearcleaner")
        for dirpath, _, names in os.walk(base):
            for name in names:
                if name.endswith(".swift"):
                    yield os.path.join(dirpath, name)

# String(localized: "...") literal, handling escaped quotes ("") inside;
# captured group spans everything up to the closing quote before )
CALL = re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"\)')

def placeholders(literal):
    """Map a Swift localized literal to its xcstrings key form.

    String interpolation of an Int expression becomes %lld; everything else
    becomes %@. Mirrors what the Swift compiler extracts into the catalog.
    Interpolation segments backslash-paren ... ) keep nested parens balanced,
    so formatBytes(size) and nested interpolations keep their delimiters.
    """
    out = []
    i = 0
    while True:
        start = literal.find("\\(", i)
        if start == -1:
            out.append(literal[i:])
            break
        out.append(literal[i:start])
        depth = 1
        j = start + 2
        while j < len(literal) and depth > 0:
            if literal[j] == "(":
                depth += 1
            elif literal[j] == ")":
                depth -= 1
            j += 1
        expr = literal[start + 2 : j - 1]
        out.append(repl_expr(expr))
        i = j
    return "".join(out)

def repl_expr(expr):
    # Int-valued expressions seen in the codebase
    if re.fullmatch(r"\s*(?:pendingLevels \?\? levels|levels|viewModel\.runningChildScanCount)\s*", expr):
        return "%lld"
    return "%@"

def main():
    scope = sys.argv[1] if len(sys.argv) > 1 else "spacelens"
    catalog = json.load(open(STRINGS))
    keys = catalog["strings"]
    langs = load_languages(catalog)
    print(f"catalog: {len(keys)} keys, {len(langs)} languages")
    print(f"scope: {scope}")

    used = {}
    for path in swift_files(scope):
        src = open(path, encoding="utf-8").read()
        for m in CALL.finditer(src):
            key = placeholders(m.group(1))
            used.setdefault(key, set()).add(os.path.basename(path))

    total = len(used)
    covered = 0
    gaps = []
    for key in sorted(used):
        entry = keys.get(key)
        if entry is None:
            gaps.append((key, sorted(used[key]), "missing key"))
            continue
        have = set(entry.get("localizations", {}).keys())
        # English is the source language; every other language must carry a value
        missing_langs = langs - have - {"en"}
        if missing_langs:
            gaps.append((key, sorted(used[key]), f"missing langs: {sorted(missing_langs)}"))
            continue
        covered += 1

    print(f"localized literals in scope: {total}")
    print(f"fully covered: {covered}")
    if gaps:
        print(f"gaps: {len(gaps)}")
        for key, files, why in gaps:
            print(f"  {key!r} in {files}: {why}")
        sys.exit(1)
    pct = 100.0 * covered / total if total else 100.0
    print(f"coverage: {pct:.1f}%")
    sys.exit(0 if covered == total else 1)

if __name__ == "__main__":
    main()