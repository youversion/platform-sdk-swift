#!/usr/bin/env node
// Decide whether a chosen release version should be marked as the GitHub
// "Latest" release.
//
// A version is "latest" only if it is a STABLE (no pre-release identifier)
// version that no existing stable tag is strictly greater than. This makes
// maintenance releases safe: a `5.2.5` cut from a `5.x` branch while `main`
// is already on `6.x` is stable-but-NOT-latest, so publishing it does not
// seize the "Latest" label from the newest major. Pre-release versions are
// never latest.
//
// Usage:
//   node scripts/release-compute-latest.mjs <version> [tags]
//
// <version>  the chosen release version (bare semver, leading `v` tolerated).
// [tags]     OPTIONAL. A comma/space/newline-separated list of existing tags
//            to compare against. When omitted, the list is read from
//            `git tag -l` in the current repo. Passing it explicitly (even as
//            an empty string) keeps the decision deterministic in tests that
//            must not depend on the ambient tag set.
//
// Stdout: "true" or "false". Always exits 0 — the caller treats this as
// advisory and defaults to latest on any error.

import { execSync } from "node:child_process";
import semver from "semver";

function parseTags(raw) {
  return raw
    .split(/[\s,]+/)
    .map((t) => t.trim().replace(/^v/, ""))
    .filter((t) => semver.valid(t) && !semver.prerelease(t));
}

function emit(value) {
  process.stdout.write(value ? "true\n" : "false\n");
  process.exit(0);
}

const version = process.argv[2];

// Unknown/invalid version → be conservative and don't claim latest.
if (!version || !semver.valid(version)) emit(false);

// Pre-releases (e.g. 5.3.0-beta.1) are never the "Latest" release.
if (semver.prerelease(version)) emit(false);

let stableTags;
if (process.argv.length >= 4) {
  // Explicit tag list provided (may be empty) — deterministic, no git.
  stableTags = parseTags(process.argv[3]);
} else {
  try {
    stableTags = parseTags(execSync("git tag -l", { encoding: "utf8" }));
  } catch {
    // No git / no tags → this is the first (hence latest) release.
    emit(true);
  }
}

// Latest iff no existing stable tag is strictly greater than this version.
// (The just-created tag equal to <version> is fine — gt is strict.)
emit(!stableTags.some((t) => semver.gt(t, version)));
