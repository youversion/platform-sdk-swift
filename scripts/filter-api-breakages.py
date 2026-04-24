#!/usr/bin/env python3
"""Post-filter swift-api-digester diagnostics.

`swift-api-digester` reports "has been renamed" for any change to a function's
selector, including the source-compatible case of adding a new parameter that
has a default value. This script removes those false positives by cross-
referencing the current API dump: a "rename" is silenced only when all of the
following hold:

  1. The base function name is unchanged (real renames are kept).
  2. The old selector's labels are a prefix of the new selector's labels
     (no reordering or relabeling of existing parameters).
  3. Every parameter added to the new signature is marked `hasDefaultArg: true`
     in the current dump (i.e. existing callers still compile).

All other diagnostics, including renames with changed base names, removed
parameters, parameter relabels, and renames where an added parameter has no
default, pass through unchanged.

Usage:
  filter-api-breakages.py <diagnostic-file> <current-dump.json>

Prints the filtered diagnostic lines to stdout. Exit code 0 always.
"""

import json
import re
import sys


RENAME_PATTERN = re.compile(
    r"^API breakage:\s+(?:func|var|let|init|subscript)\s+(.+?)\s+"
    r"has been renamed to\s+(?:func|var|let|init|subscript)\s+(.+)$"
)


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


def base_name(signature: str) -> str:
    """`Foo.bar(x:)` → `bar`; `bar(x:)` → `bar`."""
    head = signature.split("(", 1)[0]
    return head.rsplit(".", 1)[-1]


def find_function(node, printed_name: str):
    """Depth-first search for a Function node with the given printedName."""
    if isinstance(node, dict):
        if node.get("kind") == "Function" and node.get("printedName") == printed_name:
            return node
        for value in node.values():
            hit = find_function(value, printed_name)
            if hit is not None:
                return hit
    elif isinstance(node, list):
        for item in node:
            hit = find_function(item, printed_name)
            if hit is not None:
                return hit
    return None


def is_benign_param_addition(old_sig: str, new_sig: str, current_dump) -> bool:
    if base_name(old_sig) != base_name(new_sig):
        return False

    old_labels = selector_labels(old_sig)
    new_labels = selector_labels(new_sig)
    if len(new_labels) <= len(old_labels):
        return False
    if new_labels[: len(old_labels)] != old_labels:
        return False

    new_printed_name = new_sig.split(".", 1)[-1] if "." in new_sig.split("(", 1)[0] else new_sig
    function = find_function(current_dump, new_printed_name)
    if function is None:
        return False

    children = function.get("children", [])
    params = children[1:]
    if len(params) != len(new_labels):
        return False

    added_params = params[len(old_labels):]
    return all(p.get("hasDefaultArg") is True for p in added_params)


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
        match = RENAME_PATTERN.match(line)
        if match and is_benign_param_addition(match.group(1), match.group(2), current_dump):
            continue
        print(line)

    return 0


if __name__ == "__main__":
    sys.exit(main())
