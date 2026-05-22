#!/usr/bin/env node
// Validate a release version against the current tag.
//
// Called by scripts/release.sh. Extracted from an inline `node -e` block
// so the validation logic is testable in isolation and has unambiguous
// `process.argv` semantics (standard `[node, scriptPath, ...userArgs]`).
//
// Usage:
//   node scripts/release-validate.mjs <chosen-version> <current-tag>
//
// Exit codes:
//    0  valid: chosen is semver AND strictly greater than current
//   11  chosen is not valid semver
//   12  chosen is not strictly greater than current
//    1  usage error (missing args)
//
// Stderr is one of: "not_semver", "not_greater", or a usage message.
// Exit codes are the contract that release.sh switches on; the stderr
// tokens exist for human-readable logs.

import semver from "semver";

const args = process.argv.slice(2);

if (args.length < 2) {
  console.error(
    "Usage: release-validate.mjs <chosen-version> <current-tag>"
  );
  process.exit(1);
}

const [chosen, current] = args;

if (!semver.valid(chosen)) {
  console.error("not_semver");
  process.exit(11);
}

if (!semver.gt(chosen, current)) {
  console.error("not_greater");
  process.exit(12);
}

process.exit(0);
