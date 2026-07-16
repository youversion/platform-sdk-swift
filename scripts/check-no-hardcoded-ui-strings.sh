#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOWLIST="${ROOT}/config/i18n/hardcoded-string-allowlist.txt"

if [[ ! -f "$ALLOWLIST" ]]; then
  echo "Allowlist file not found: $ALLOWLIST"
  exit 1
fi

export ROOT ALLOWLIST
python3 - <<'PY'
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

root = Path(os.environ["ROOT"])
allowlist_path = Path(os.environ["ALLOWLIST"])

scan_dirs = [
    root / "Sources/YouVersionPlatformUI",
    root / "Sources/YouVersionPlatformReader",
]

# Raw string literal arguments to common SwiftUI user-facing APIs.
# Keep in sync with the hardcoded_ui_string custom rule in .swiftlint.yml.
PATTERNS = [
    re.compile(r'\bText\s*\(\s*"([^"]*)"'),
    re.compile(r'\bButton\s*\(\s*"([^"]*)"'),
    re.compile(r'\bLabel\s*\(\s*"([^"]*)"'),
    re.compile(r'\.navigationTitle\s*\(\s*"([^"]*)"'),
    re.compile(r'\.navigationBarTitle\s*\(\s*"([^"]*)"'),
    re.compile(r'\.accessibilityLabel\s*\(\s*"([^"]*)"'),
    re.compile(r'\.accessibilityHint\s*\(\s*"([^"]*)"'),
    re.compile(r'\bconfirmationDialog\s*\(\s*"([^"]*)"'),
    re.compile(r'\balert\s*\(\s*"([^"]*)"'),
]


def load_allowlist() -> list[tuple[str, int | None, str | None]]:
    """Parse entries of the form path, path:pattern, or path:line:pattern."""
    entries: list[tuple[str, int | None, str | None]] = []
    for raw in allowlist_path.read_text(encoding="utf-8").splitlines():
        entry = raw.strip()
        if not entry or entry.startswith("#"):
            continue
        parts = entry.split(":", 2)
        if len(parts) == 3 and parts[1].strip().isdigit():
            entries.append((parts[0].strip(), int(parts[1]), parts[2].strip()))
        elif len(parts) >= 2:
            file_part, pattern = entry.split(":", 1)
            entries.append((file_part.strip(), None, pattern.strip()))
        else:
            entries.append((entry, None, None))
    return entries


def is_allowlisted(rel_path: str, line_number: int, line: str, allowlist) -> bool:
    for file_part, lineno, pattern in allowlist:
        if file_part not in rel_path:
            continue
        if lineno is not None and lineno != line_number:
            continue
        if pattern is None or pattern in line:
            return True
    return False


def strip_comments(line: str, in_block_comment: bool) -> tuple[str, str, bool]:
    """Return (code with strings kept, code with string contents blanked, block-comment state).

    Drops trailing // comments and /* */ bodies without being fooled by
    delimiters inside string literals (e.g. Text("https://...")).
    """
    kept: list[str] = []
    blanked: list[str] = []
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
                blanked.append(ch)
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
        blanked.append(ch)
        if ch == '"':
            in_string = True
        i += 1
    return "".join(kept), "".join(blanked), in_block_comment


class PreviewTracker:
    """Skips #Preview blocks, including the single-line `#Preview { ... }` form."""

    def __init__(self) -> None:
        self.depth = 0

    def consume(self, code_line: str) -> bool:
        """Feed one string-blanked code line; True means the line is preview scaffolding."""
        if self.depth > 0:
            self.depth = max(self.depth + code_line.count("{") - code_line.count("}"), 0)
            return True
        if re.search(r"#Preview\b", code_line):
            self.depth = max(code_line.count("{") - code_line.count("}"), 0)
            return True
        return False


def should_skip_literal(literal: str) -> bool:
    # Single-character glyphs (and empty placeholders) are not localizable copy.
    return len(literal) <= 1


def scan_file(path: Path, allowlist) -> list[tuple[int, str, str]]:
    rel_path = path.relative_to(root).as_posix()
    violations: list[tuple[int, str, str]] = []
    preview = PreviewTracker()
    in_block_comment = False

    for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code, blanked, in_block_comment = strip_comments(line, in_block_comment)
        if preview.consume(blanked):
            continue

        for pattern in PATTERNS:
            match = pattern.search(code)
            if not match:
                continue
            literal = match.group(1)
            if should_skip_literal(literal):
                continue
            if is_allowlisted(rel_path, index, code, allowlist):
                continue
            violations.append((index, literal, line.strip()))
            break

    return violations


allowlist = load_allowlist()
all_violations: list[tuple[str, int, str, str]] = []

for scan_dir in scan_dirs:
    if not scan_dir.is_dir():
        continue
    for path in sorted(scan_dir.rglob("*.swift")):
        for line_number, literal, line in scan_file(path, allowlist):
            rel_path = path.relative_to(root).as_posix()
            all_violations.append((rel_path, line_number, literal, line))

if not all_violations:
    print("Hardcoded UI string check passed.")
    sys.exit(0)

print("::error title=Hardcoded UI strings detected::User-facing copy must use String.localized(...). See docs/localization-guardrails.md")
print("")
print("Hardcoded UI string violations:")
for rel_path, line_number, literal, line in all_violations:
    print(f"  {rel_path}:{line_number}: \"{literal}\" — {line}")
print("")
print("Fix by using String.localized(\"dotted.key\") with keys added upstream in platform-localization.")
sys.exit(1)
PY
