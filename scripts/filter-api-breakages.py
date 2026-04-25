#!/usr/bin/env python3
"""Post-filter swift-api-digester diagnostics.

Silences digester "breakages" that are not real source-incompatible changes:

  1. Renames caused by adding a parameter with a default value to an existing
     function (the digester reports "has been renamed to"). Suppressed only
     when all of these hold:
       - The base name is unchanged (real renames are kept).
       - The old selector's labels are a prefix of the new selector's labels.
       - Every added parameter has `hasDefaultArg: true` in the current dump.

  2. Removals of a callable when a surviving overload covers the same call
     sites (the digester reports "has been removed" for constructors and
     subscripts in cases where functions would have been reported as renamed).
     Suppressed only when the current dump contains a callable with the same
     base name whose selector extends the removed one with only defaulted
     parameters.

  3. Conformance diffs against language-synthesized protocols like `Sendable`,
     `Copyable`, and `Escapable`. These protocols are inferred by the compiler
     based on a type's structure, so the set a given toolchain emits for a
     given type can drift between Swift releases even when the library's
     declarations are unchanged. Library authors don't declare these
     conformances explicitly, so diffs against them are toolchain noise rather
     than API changes.

All other diagnostics pass through unchanged.

Usage:
  filter-api-breakages.py <diagnostic-file> <current-dump.json>

Prints the filtered diagnostic lines to stdout. Exit code 0 always.
"""

import json
import re
import sys


RENAME_PATTERN = re.compile(
    r"^API breakage:\s+\w+\s+(.+?)\s+has been renamed to\s+\w+\s+(.+)$"
)

REMOVAL_PATTERN = re.compile(
    r"^API breakage:\s+\w+\s+(.+?)\s+has been removed$"
)

CONFORMANCE_PATTERN = re.compile(
    r"^API breakage:\s+.+\s+has (?:added|removed) conformance to\s+(\S+)$"
)

# Protocols the Swift compiler synthesizes conformance to based on a type's
# structure rather than explicit declaration. The set a toolchain emits shifts
# between Swift releases, so diffs against these are not real API changes.
SYNTHESIZED_PROTOCOLS = frozenset({
    "Sendable",
    "SendableMetatype",
    "Copyable",
    "Escapable",
    "BitwiseCopyable",
})


def selector_labels(signature: str) -> list[str]:
    """Return the argument labels from `foo(a:b:c:)` → ['a', 'b', 'c']. Empty
    list for `foo()` or bare `foo`."""
    match = re.search(r"\((.*)\)$", signature)
    if not match:
        return []
    inside = match.group(1)
    if not inside:
        return []
    return [part for part in inside.rstrip(":").split(":") if part]


def split_owner(signature: str) -> tuple[str | None, str]:
    """`Foo.bar(x:)` → ('Foo', 'bar(x:)'); `bar(x:)` → (None, 'bar(x:)').

    Owner is everything before the rightmost `.` in the part preceding `(`.
    Used to ensure a free function and a method on a type with the same base
    name are not treated as overloads of each other.
    """
    head, _, tail = signature.partition("(")
    if "." in head:
        owner, name = head.rsplit(".", 1)
        return owner, f"{name}({tail}"
    return None, signature


def base_name(signature: str) -> str:
    """`Foo.bar(x:)` → `bar`; `bar(x:)` → `bar`."""
    return split_owner(signature)[1].split("(", 1)[0]


CALLABLE_KINDS = frozenset({"Function", "Constructor", "Subscript"})


def iter_callables_with_owner(node, owner_stack=None):
    """Yield (callable_node, owner_string_or_None) for every callable in the
    dump, where owner is the dot-joined chain of enclosing type names.

    The digester uses `kind: "TypeDecl"` for every declared type (struct,
    class, enum, etc.); the specific declKind matters for human readability
    but not for owner-chain construction. Any TypeDecl introduces a scope.
    """
    if owner_stack is None:
        owner_stack = []
    if isinstance(node, dict):
        kind = node.get("kind")
        if kind in CALLABLE_KINDS:
            owner = ".".join(owner_stack) if owner_stack else None
            yield node, owner
        if kind == "TypeDecl":
            type_name = node.get("printedName") or node.get("name") or ""
            child_stack = owner_stack + [type_name]
        else:
            child_stack = owner_stack
        for value in node.values():
            yield from iter_callables_with_owner(value, child_stack)
    elif isinstance(node, list):
        for item in node:
            yield from iter_callables_with_owner(item, owner_stack)


def find_callable_in_owner(current_dump, owner: str | None, printed_name: str):
    for callable_node, found_owner in iter_callables_with_owner(current_dump):
        if found_owner == owner and callable_node.get("printedName") == printed_name:
            return callable_node
    return None


def is_benign_param_addition(old_sig: str, new_sig: str, current_dump) -> bool:
    """True when `old_sig` → `new_sig` is a direct rename diagnostic caused
    only by appending parameters that all have default values to the same
    declaration (same owner, same base name)."""
    if base_name(old_sig) != base_name(new_sig):
        return False

    old_labels = selector_labels(old_sig)
    new_labels = selector_labels(new_sig)
    if len(new_labels) <= len(old_labels):
        return False
    if new_labels[: len(old_labels)] != old_labels:
        return False

    # The digester is inconsistent about whether the right-hand signature
    # carries the owner prefix. Use the left-hand owner as truth, and look
    # the new declaration up in that scope only.
    old_owner, _ = split_owner(old_sig)
    _, new_local = split_owner(new_sig)
    declaration = find_callable_in_owner(current_dump, old_owner, new_local)
    if declaration is None:
        return False

    children = declaration.get("children", [])
    params = children[1:]
    if len(params) != len(new_labels):
        return False

    added_params = params[len(old_labels):]
    return all(p.get("hasDefaultArg") is True for p in added_params)


def is_benign_removal(old_sig: str, current_dump) -> bool:
    """True when a 'has been removed' diagnostic is covered by a surviving
    overload in the same owner whose signature extends the removed one with
    only defaulted parameters (so existing call sites still compile)."""
    old_owner, _ = split_owner(old_sig)
    old_base = base_name(old_sig)
    old_labels = selector_labels(old_sig)

    for candidate, owner in iter_callables_with_owner(current_dump):
        if owner != old_owner:
            continue
        if candidate.get("name") != old_base:
            continue
        candidate_labels = selector_labels(candidate.get("printedName", ""))
        if len(candidate_labels) <= len(old_labels):
            continue
        if candidate_labels[: len(old_labels)] != old_labels:
            continue
        params = candidate.get("children", [])[1:]
        if len(params) != len(candidate_labels):
            continue
        added = params[len(old_labels):]
        if all(p.get("hasDefaultArg") is True for p in added):
            return True
    return False


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: filter-api-breakages.py <diagnostic-file> <current-dump.json>",
            file=sys.stderr,
        )
        return 2

    diag_path, dump_path = sys.argv[1], sys.argv[2]
    with open(dump_path) as f:
        current_dump = json.load(f)
    with open(diag_path) as f:
        lines = f.read().splitlines()

    for line in lines:
        if not line.startswith("API breakage:"):
            continue
        rename_match = RENAME_PATTERN.match(line)
        if rename_match and is_benign_param_addition(
            rename_match.group(1), rename_match.group(2), current_dump
        ):
            continue
        removal_match = REMOVAL_PATTERN.match(line)
        if removal_match and is_benign_removal(removal_match.group(1), current_dump):
            continue
        conformance_match = CONFORMANCE_PATTERN.match(line)
        if conformance_match and conformance_match.group(1) in SYNTHESIZED_PROTOCOLS:
            continue
        print(line)

    return 0


if __name__ == "__main__":
    sys.exit(main())
