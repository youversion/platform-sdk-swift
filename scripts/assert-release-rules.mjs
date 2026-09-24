#!/usr/bin/env node
// Assert that .releaserc.json maps commit types to the release types we intend.
//
// Without releaseRules the stock conventionalcommits preset bumps on `feat` and
// `fix` whatever their scope, so a CI-only PR publishes an SDK version with
// nothing in it for a consumer to uptake. That is not hypothetical: PR #273
// previewed as a minor off a `feat(ci):` commit before this was added.
//
// The `breaking` entry has to come first. Custom rules are consulted before the
// preset's own, so without it a `feat(ci)!` carrying a BREAKING CHANGE footer
// matches the ci rule and resolves to no release at all.
//
// Run via `node scripts/assert-release-rules.mjs`; wired into
// scripts/test-release-scripts.sh. Exits 1 on the first mismatch.

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { analyzeCommits } from "@semantic-release/commit-analyzer";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// Read the analyzer's config the same way scripts/preview-release.mjs does, so
// this asserts the file the release actually uses rather than a copy of it.
const releaserc = JSON.parse(readFileSync(join(ROOT, ".releaserc.json"), "utf8"));
const entry = releaserc.plugins.find(
  (p) => Array.isArray(p) && p[0] === "@semantic-release/commit-analyzer",
);
if (!entry) {
  console.error("@semantic-release/commit-analyzer is not configured in .releaserc.json");
  process.exit(1);
}
const pluginConfig = entry[1] ?? {};

const EXPECTED = [
  ["feat: add a public API", "minor"],
  ["fix: correct a rendering bug", "patch"],
  ["feat!: drop a public API\n\nBREAKING CHANGE: gone", "major"],
  // CI-only work ships no library code, so it must not move the SDK version.
  ["feat(ci): add a workflow", null],
  ["fix(ci): repair a workflow", null],
  ["ci: tweak a workflow", null],
  ["chore: housekeeping", null],
  // A breaking change stays breaking even when it is scoped to ci.
  ["feat(ci)!: drop a workflow input\n\nBREAKING CHANGE: gone", "major"],
];

let failed = 0;
for (const [message, expected] of EXPECTED) {
  const actual = await analyzeCommits(pluginConfig, {
    commits: [{ hash: "0".repeat(40), message }],
    logger: { log: () => {} },
    cwd: ROOT,
    env: {},
  });
  const subject = message.split("\n")[0];
  if (actual !== expected) {
    console.error(`  ${subject} -> ${actual}, expected ${expected}`);
    failed += 1;
  }
}

if (failed > 0) {
  console.error(`${failed} release-rule mismatch(es); see .releaserc.json releaseRules.`);
  process.exit(1);
}
console.log(`Release rules behave as intended (${EXPECTED.length} cases).`);
