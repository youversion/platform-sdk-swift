#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="${ROOT}/Sources/YouVersionPlatformUI/Resources/Localizable.xcstrings"
SCAN_DIRS=(
  "${ROOT}/Sources/YouVersionPlatformUI"
  "${ROOT}/Sources/YouVersionPlatformReader"
)

if [[ ! -f "$CATALOG" ]]; then
  echo "String catalog not found: $CATALOG"
  exit 1
fi

export ROOT CATALOG
python3 - <<'PY'
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

root = Path(os.environ["ROOT"])
catalog_path = Path(os.environ["CATALOG"])

scan_dirs = [
    root / "Sources/YouVersionPlatformUI",
    root / "Sources/YouVersionPlatformReader",
]

KEY_PATTERN = re.compile(r'(?:String\.)?localized\(\s*"([^"]+)"\s*\)')


def catalog_keys_with_english(catalog: dict) -> set[str]:
    """Keys that carry an explicit English localization.

    The catalog's sourceLanguage is en, but these are dotted keys, not natural-language
    source strings — an entry without an en value renders the raw key at runtime.
    """
    strings = catalog.get("strings", {})
    return {
        key
        for key, entry in strings.items()
        if "en" in entry.get("localizations", {})
    }


# Keep in sync with strip_comments in scripts/check-no-hardcoded-ui-strings.sh
def strip_comments(line: str, in_block_comment: bool) -> tuple[str, bool]:
    """Return (code with strings kept, block-comment state)."""
    kept: list[str] = []
    in_string = False
    i = 0
    n = len(line)
    while i < n:
        ch = line[i]
        if in_block_comment:
            if line.startswith("*/", i):
                in_block_comment = False
                i += 2
            else:
                i += 1
            continue
        if in_string:
            if ch == "\\" and i + 1 < n:
                kept.append(line[i : i + 2])
                i += 2
                continue
            kept.append(ch)
            if ch == '"':
                in_string = False
            i += 1
            continue
        if line.startswith("//", i):
            break
        if line.startswith("/*", i):
            in_block_comment = True
            i += 2
            continue
        kept.append(ch)
        if ch == '"':
            in_string = True
        i += 1
    return "".join(kept), in_block_comment


def extract_keys_from_sources() -> set[str]:
    keys: set[str] = set()
    for scan_dir in scan_dirs:
        if not scan_dir.is_dir():
            continue
        for path in scan_dir.rglob("*.swift"):
            in_block_comment = False
            code_lines: list[str] = []
            for line in path.read_text(encoding="utf-8").splitlines():
                code, in_block_comment = strip_comments(line, in_block_comment)
                code_lines.append(code)
            keys.update(KEY_PATTERN.findall("\n".join(code_lines)))
    return keys


catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
catalog_keys = catalog_keys_with_english(catalog)
source_keys = extract_keys_from_sources()

missing = sorted(key for key in source_keys if key not in catalog_keys)

if not missing:
    print(f"Localization key existence check passed ({len(source_keys)} keys).")
    sys.exit(0)

print("::error title=Missing localization keys::String.localized keys must exist in Localizable.xcstrings (English). Add keys upstream in platform-localization.")
print("")
print("Keys referenced in SDK sources but missing from the catalog:")
for key in missing:
    print(f"  - {key}")
print("")
print("See docs/localization-guardrails.md")
sys.exit(1)
PY
