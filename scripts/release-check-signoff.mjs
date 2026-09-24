#!/usr/bin/env node
// Verify a major release was authorized, at release time rather than merge time.
//
// Merge-time enforcement lives in .github/workflows/major-release-signoff.yml and
// binds a signoff to one PR head SHA. It cannot cover what is actually published:
// the version is a human-typed workflow_dispatch input, so a major can be cut
// without any breaking change having been signed off.
//
// This closes that: for a major bump, some PR in the release range must carry a
// successful `major-release-signoff` status naming this exact version. The status
// description is written by the gate as "Major v<version> signed off by <login>.".
//
// Usage:
//   node scripts/release-check-signoff.mjs <requested-version> <base-tag> < records.json
//
// <base-tag> is the tag this release supersedes, NOT necessarily the newest tag:
// on a resume the requested version is already tagged, and comparing against it
// would read every major as "no major bump here".
//
// stdin is a JSON array of the signoff statuses found on the PRs in the release
// range. Gathering is the caller's job (scripts/collect-release-signoffs.sh) so
// the decision stays pure and testable:
//   [{"pr": 272, "state": "success", "description": "Major v6.0.0 signed off by jhampton."}]
//
// Exit 0 when the release may proceed, 1 when it may not. The reason goes to
// stderr as the operator message; the caller just propagates the failure.

import { readFileSync } from "node:fs";
import semver from "semver";

function block(message) {
  console.error(message);
  process.exit(1);
}

const args = process.argv.slice(2);

if (args.length < 2) {
  block("Usage: release-check-signoff.mjs <requested-version> <base-tag> < records.json");
}

const [requested, baseTag] = args;

if (!semver.valid(requested)) {
  block(`'${requested}' is not valid semver, so the release cannot be authorized.`);
}

// `git describe` on a repo with no tags yields nothing; release.sh substitutes
// 0.0.0. Coerce so a leading `v` never changes the answer.
const base = semver.coerce(baseTag) ?? semver.parse("0.0.0");

// A base at or ahead of the version being released is always a caller bug, and
// the shape it takes is dangerous: passing the newest tag on a resume hands this
// the version it is about to publish, which then reads as no bump at all and
// skips every check below. Refuse rather than silently authorize.
if (!semver.gt(requested, base)) {
  block(
    `Base '${baseTag}' is not older than v${requested}; the release range would be empty. ` +
      `Pass the tag this release supersedes, not the newest tag.`,
  );
}

if (semver.major(requested) === semver.major(base)) {
  console.error(`v${requested} is not a major bump over ${baseTag}; no signoff required.`);
  process.exit(0);
}

let records;
try {
  records = JSON.parse(readFileSync(0, "utf8") || "[]");
} catch {
  block("Could not read the signoff records on stdin as JSON.");
}
if (!Array.isArray(records)) {
  block("The signoff records on stdin are not a JSON array.");
}

// A failing signoff anywhere in the range means a breaking change reached main
// without approval. Report it before looking for a success: publishing on the
// strength of a different PR's signoff would ship exactly what the gate refused.
const failing = records.find((r) => r?.state === "failure");
if (failing) {
  block(
    `PR #${failing.pr} has a failing major-release-signoff. Resolve it before publishing v${requested}.`,
  );
}

// A PR the gate never evaluated is not evidence of anything. Accepting the
// release on a different PR's signoff would publish an unreviewed breaking
// change under cover of a reviewed one.
const missing = records.find((r) => r?.state === "missing");
if (missing) {
  block(
    `PR #${missing.pr} has no major-release-signoff status, so it was never evaluated for ` +
      `breaking changes. Re-run the gate by commenting on that PR, then re-dispatch.`,
  );
}

// Match the version as a whole token so v6.0.0 is never satisfied by a signoff
// for v6.0.0-beta.1 or v6.0.01.
const names = new RegExp(
  `(^|[^0-9A-Za-z.])v${requested.replace(/\./g, "\\.")}([^0-9A-Za-z.-]|$)`,
);
const match = records.find(
  (r) => r?.state === "success" && typeof r.description === "string" && names.test(r.description),
);

if (!match) {
  block(
    `v${requested} is a major release, but no PR merged since ${baseTag} carries a ` +
      `major-release-signoff naming that version. Sign off on the breaking change's PR, ` +
      `or publish the version the range actually justifies.`,
  );
}

const approver = /signed off by (\S+?)\.?$/.exec(match.description)?.[1] ?? "unknown";
console.error(`v${requested} authorized by ${approver} (PR #${match.pr}).`);
process.exit(0);
