#!/usr/bin/env node
// Warn (do not block) when the chosen release version is more than one
// major above the analyzer-calculated version. Surfaces "did you mean
// that?" without preventing intentional jumps (e.g., a recovery release
// that intentionally crosses a major boundary).
//
// Called by scripts/release.sh. Extracted from an inline `node -e` block
// so the logic is testable and `process.argv` semantics are standard.
//
// Usage:
//   node scripts/release-warn-version-jump.mjs <chosen> <calculated>
//
// Always exits 0. Prints a single warning line to stderr when the gap
// exceeds one major. If <calculated> is not valid semver, exits silently
// (the analyzer may legitimately produce no calculated value on a fresh
// repo with no prior tag).

import semver from "semver";

const [chosen, calculated] = process.argv.slice(2);

if (!semver.valid(calculated)) {
  process.exit(0);
}

if (semver.major(chosen) > semver.major(calculated) + 1) {
  console.error(
    `⚠️  Chosen version ${chosen} is more than one major above calculated ${calculated}. Proceeding, but double-check this is intentional.`
  );
}

process.exit(0);
