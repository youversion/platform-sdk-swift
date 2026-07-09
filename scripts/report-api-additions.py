#!/usr/bin/env python3
"""Report public API additions between swift-api-digester dumps.

The stability check intentionally treats additive public API as allowed, but
release reviewers still need to see what new surface area is being exposed.
This script compares baseline and current digester JSON by USR, then groups
new declarations by the Swift source file that appears to implement them.

Usage:
  report-api-additions.py <baseline-dir> <current-dir> <sources-dir> <module>...
"""

from __future__ import annotations

from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys


DECLARATION_KINDS = frozenset(
    {
        "AssociatedType",
        "Constructor",
        "Function",
        "Subscript",
        "TypeAlias",
        "TypeDecl",
        "Var",
    }
)


TYPE_DECL_KINDS = {
    "Class": "class",
    "Enum": "enum",
    "Protocol": "protocol",
    "Struct": "struct",
}

SWIFT_ATTRIBUTE_PATTERN = r"@[A-Za-z_][A-Za-z0-9_]*(?:\([^)]*\))?\s+"
SWIFT_DECLARATION_PREFIX_PATTERN = rf"(?:(?:public|open|final)\s+|{SWIFT_ATTRIBUTE_PATTERN})*"


@dataclass(frozen=True)
class Scope:
    name: str
    start: int
    end: int


@dataclass(frozen=True)
class SourceMatch:
    path: Path
    index: int
    owner: str | None
    score: int


@dataclass(frozen=True)
class Addition:
    module: str
    kind: str
    decl_kind: str | None
    name: str
    printed_name: str
    usr: str
    context: tuple[str, ...]
    implicit: bool
    static: bool
    is_let: bool


def load_dump(path: Path) -> dict:
    with path.open() as file:
        return json.load(file)


def collect_declarations(
    node: dict | list,
    module: str,
    context: tuple[str, ...] = (),
) -> list[Addition]:
    declarations: list[Addition] = []

    if isinstance(node, list):
        for child in node:
            declarations.extend(collect_declarations(child, module, context))
        return declarations

    if not isinstance(node, dict):
        return declarations

    kind = node.get("kind")
    node_module = node.get("moduleName", module)
    if kind in DECLARATION_KINDS and node.get("usr") and node_module == module:
        declarations.append(
            Addition(
                module=module,
                kind=kind,
                decl_kind=node.get("declKind"),
                name=node.get("name") or "",
                printed_name=node.get("printedName") or node.get("name") or "",
                usr=node["usr"],
                context=context,
                implicit=bool(node.get("implicit")),
                static=bool(node.get("static")),
                is_let=bool(node.get("isLet")),
            )
        )

    if kind == "TypeDecl":
        type_name = node.get("printedName") or node.get("name") or ""
        child_context = context + (type_name,)
    else:
        child_context = context

    for child in node.get("children", []) or []:
        declarations.extend(collect_declarations(child, module, child_context))

    return declarations


def public_declarations(path: Path, module: str) -> dict[str, Addition]:
    dump = load_dump(path)
    root = dump["ABIRoot"]
    return {declaration.usr: declaration for declaration in collect_declarations(root, module)}


def matching_brace_index(text: str, open_brace: int) -> int:
    depth = 0
    for index in range(open_brace, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
    return len(text)


def source_scopes(text: str) -> list[Scope]:
    pattern = re.compile(
        rf"\b{SWIFT_DECLARATION_PREFIX_PATTERN}"
        r"(?:extension|struct|class|enum|protocol|actor)\s+"
        r"([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?)"
        r"[^{}]*\{"
    )
    scopes: list[Scope] = []
    for match in pattern.finditer(text):
        open_brace = text.find("{", match.start())
        scopes.append(
            Scope(
                name=match.group(1),
                start=open_brace,
                end=matching_brace_index(text, open_brace),
            )
        )
    return scopes


def owner_at(scopes: list[Scope], index: int) -> str | None:
    containing = [scope for scope in scopes if scope.start < index < scope.end]
    if not containing:
        return None
    containing.sort(key=lambda scope: scope.start)
    names: list[str] = []
    for scope in containing:
        if "." in scope.name:
            names = scope.name.split(".")
        else:
            names.append(scope.name)
    return ".".join(names)


def regex_for_addition(addition: Addition) -> re.Pattern[str]:
    escaped_name = re.escape(addition.name)
    if addition.kind == "TypeDecl":
        return re.compile(
            rf"\b{SWIFT_DECLARATION_PREFIX_PATTERN}"
            rf"(?:struct|class|enum|protocol|actor)\s+{escaped_name}\b"
        )
    if addition.kind == "Constructor":
        return re.compile(r"\binit\s*\(")
    if addition.decl_kind == "EnumElement":
        return re.compile(rf"\bcase\s+{escaped_name}\b")
    if addition.kind == "Function":
        return re.compile(rf"\bfunc\s+{escaped_name}\s*\(")
    if addition.kind == "Subscript":
        return re.compile(r"\bsubscript\s*\(")
    if addition.kind == "TypeAlias":
        return re.compile(rf"\btypealias\s+{escaped_name}\b")
    if addition.kind == "AssociatedType":
        return re.compile(rf"\bassociatedtype\s+{escaped_name}\b")
    return re.compile(rf"\b(?:var|let)\s+{escaped_name}\b")


def context_score(addition: Addition, owner: str | None) -> int:
    if not owner:
        return 0
    if not addition.context:
        return 10
    owner_parts = owner.split(".")
    context_parts = list(addition.context)
    if owner_parts[-len(context_parts):] == context_parts:
        return 40
    if context_parts[-1] in owner_parts:
        return 20
    return 0


def find_source_match(addition: Addition, source_files: list[Path]) -> SourceMatch | None:
    pattern = regex_for_addition(addition)
    best: SourceMatch | None = None

    for path in source_files:
        text = path.read_text()
        context_is_present = any(part in text for part in addition.context)
        if (
            addition.name
            and addition.name not in text
            and addition.kind != "Constructor"
            and not context_is_present
        ):
            continue

        scopes = source_scopes(text)
        for match in pattern.finditer(text):
            owner = owner_at(scopes, match.start())
            matched_context_score = context_score(addition, owner)
            if addition.context and matched_context_score == 0:
                continue
            score = 50 + matched_context_score
            if addition.context and any(part in text for part in addition.context):
                score += 10
            if addition.kind == "Constructor" and addition.context and addition.context[-1] not in text:
                continue
            candidate = SourceMatch(path=path, index=match.start(), owner=owner, score=score)
            if best is None or candidate.score > best.score:
                best = candidate

        if addition.context and addition.context[-1] in text:
            owner = addition.context[-1]
            owner_pattern = re.compile(
                rf"\b{SWIFT_DECLARATION_PREFIX_PATTERN}"
                rf"(?:extension|struct|class|enum|protocol|actor)\s+{re.escape(owner)}\b"
            )
            owner_match = owner_pattern.search(text)
            if owner_match is None:
                continue
            score = 45
            index = owner_match.start()
            candidate = SourceMatch(path=path, index=index, owner=owner, score=score)
            if best is None or candidate.score > best.score:
                best = candidate

    return best


def declaration_owner(addition: Addition, source_match: SourceMatch | None) -> str | None:
    if addition.context:
        owner = ".".join(addition.context)
        if source_match and source_match.owner and source_match.owner.endswith(f".{owner}"):
            return source_match.owner
        return owner
    if source_match and source_match.owner and addition.kind != "TypeDecl":
        return source_match.owner
    return None


def qualified_name(addition: Addition, source_match: SourceMatch | None) -> str:
    owner = declaration_owner(addition, source_match)
    if addition.kind == "Constructor":
        return f"{owner}.init{addition.printed_name.removeprefix('init')}" if owner else addition.printed_name
    if addition.name == "__derived_struct_equals" and owner:
        return f"{owner}.=="
    if owner:
        return f"{owner}.{addition.printed_name}"
    return addition.printed_name


def display_label(addition: Addition, source_match: SourceMatch | None) -> str:
    name = qualified_name(addition, source_match)
    prefix = "static " if addition.static else ""

    if addition.kind == "TypeDecl":
        decl_kind = TYPE_DECL_KINDS.get(addition.decl_kind or "", (addition.decl_kind or "type").lower())
        if addition.context:
            name = ".".join(addition.context + (addition.printed_name,))
        return f"{decl_kind} {name}"
    if addition.kind == "Constructor":
        return name
    if addition.decl_kind == "EnumElement":
        return f"case {name}"
    if addition.kind == "Function":
        return f"{prefix}func {name}"
    if addition.kind == "Subscript":
        return f"{prefix}subscript {name}"
    if addition.kind == "TypeAlias":
        return f"typealias {name}"
    if addition.kind == "AssociatedType":
        return f"associatedtype {name}"

    storage = "let" if addition.is_let else "var"
    return f"{prefix}{storage} {name}"


def source_files_for_module(sources_dir: Path, module: str) -> list[Path]:
    module_dir = sources_dir / module
    if not module_dir.exists():
        return []
    return sorted(module_dir.rglob("*.swift"))


def print_report(
    additions_by_path: dict[Path | None, list[tuple[Addition, SourceMatch | None]]],
    sources_dir: Path,
) -> None:
    total = sum(len(items) for items in additions_by_path.values())
    print("==============================================================")
    print(" PUBLIC API additions since baseline")
    print("==============================================================")

    if total == 0:
        print("No public API additions detected.")
        return

    print(f"{total} added declaration(s).")
    print()

    def sort_key(path: Path | None) -> str:
        return "zzzz_unmapped" if path is None else path.as_posix()

    for path in sorted(additions_by_path, key=sort_key):
        items = additions_by_path[path]
        if path is None:
            print("Unmapped")
        else:
            try:
                display_path = path.relative_to(sources_dir.parent)
            except ValueError:
                display_path = path
            print(display_path.parent.as_posix())
            print(f"  {display_path.name}")

        explicit = [(addition, match) for addition, match in items if not addition.implicit]
        implicit = [(addition, match) for addition, match in items if addition.implicit]

        for addition, match in sorted(explicit, key=lambda item: display_label(*item)):
            print(f"    - {display_label(addition, match)}")

        if implicit:
            print("    Synthesized or associated declarations:")
            for addition, match in sorted(implicit, key=lambda item: display_label(*item)):
                print(f"    - {display_label(addition, match)}")

        print()


def main() -> int:
    if len(sys.argv) < 5:
        print(
            "usage: report-api-additions.py <baseline-dir> <current-dir> <sources-dir> <module>...",
            file=sys.stderr,
        )
        return 2

    baseline_dir = Path(sys.argv[1])
    current_dir = Path(sys.argv[2])
    sources_dir = Path(sys.argv[3])
    modules = sys.argv[4:]

    additions_by_path: dict[Path | None, list[tuple[Addition, SourceMatch | None]]] = {}

    for module in modules:
        baseline = public_declarations(baseline_dir / f"{module}.json", module)
        current = public_declarations(current_dir / f"{module}.json", module)
        source_files = source_files_for_module(sources_dir, module)

        added_usrs = sorted(current.keys() - baseline.keys())
        for usr in added_usrs:
            addition = current[usr]
            source_match = find_source_match(addition, source_files)
            path = source_match.path if source_match else None
            additions_by_path.setdefault(path, []).append((addition, source_match))

    print_report(additions_by_path, sources_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
