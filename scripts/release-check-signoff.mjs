#!/usr/bin/env node
// Verify a major release was authorized, at release time rather than merge time.
//
// Merge-time enforcement lives in .github/workflows/major-release-signoff.yml and
// binds a signoff to one PR head SHA. It cannot cover what is actually published:
// release.yml takes the version as a human-typed workflow_dispatch input, so a
// major can be cut without any breaking change having been signed off.
//
// This closes that: for a major bump, some PR in the release range must carry a
// successful `major-release-signoff` status naming this exact version. The status
// description is written by the gate as "Major v<version> signed off by <login>.".
//
// Usage:
//   node scripts/release-check-signoff.mjs <requested-version> <current-tag> < records.json
//
// stdin is a JSON array of the signoff statuses found on the PRs in the release
// range. Gathering is the caller's job (release.yml) so the decision stays pure
// and testable:
//   [{"pr": 272, "state": "success", "description": "Major v6.0.0 signed off by jhampton."}]
//
// Exit codes:
//    0  authorized, or not a major bump (nothing to authorize)
//   21  major bump with no signoff naming this version
//   22  a PR in the range has a failing signoff status
//    1  usage error, or stdin is not a JSON array
//
// Stderr is one of: "not_major", "authorized_by=<login>", "no_signoff",
// "failing_signoff=<pr>", or a usage message. Exit codes are the contract;
// the stderr tokens exist for human-readable logs.

import { readFileSync } from "node:fs";
import semver from "semver";

const args = process.argv.slice(2);

if (args.length < 2) {
  console.error(
    "Usage: release-check-signoff.mjs <requested-version> <current-tag> < records.json"
  );
  process.exit(1);
}

const [requested, currentTag] = args;

if (!semver.valid(requested)) {
  console.error("not_semver");
  process.exit(1);
}

// `git describe` on a repo with no tags yields nothing; release.sh substitutes
// 0.0.0. Coerce so a leading `v` never changes the answer.
const current = semver.coerce(currentTag) ?? semver.parse("0.0.0");

if (semver.major(requested) === semver.major(current)) {
  console.error("not_major");
  process.exit(0);
}

let records;
try {
  records = JSON.parse(readFileSync(0, "utf8") || "[]");
} catch {
  console.error("stdin is not valid JSON");
  process.exit(1);
}
if (!Array.isArray(records)) {
  console.error("stdin is not a JSON array");
  process.exit(1);
}

// A failing signoff anywhere in the range means a breaking change reached main
// without approval. Report it before looking for a success: publishing on the
// strength of a different PR's signoff would ship exactly what the gate refused.
const failing = records.find((r) => r?.state === "failure");
if (failing) {
  console.error(`failing_signoff=${failing.pr}`);
  process.exit(22);
}

// Match the version as a whole token so v6.0.0 is never satisfied by a signoff
// for v6.0.0-beta.1 or v6.0.01.
const names = new RegExp(`(^|[^0-9A-Za-z.])v${semver.valid(requested).replace(/\./g, "\\.")}([^0-9A-Za-z.-]|$)`);
const match = records.find(
  (r) => r?.state === "success" && typeof r.description === "string" && names.test(r.description)
);

if (!match) {
  console.error("no_signoff");
  process.exit(21);
}

const approver = /signed off by (\S+?)\.?$/.exec(match.description)?.[1] ?? "unknown";
console.error(`authorized_by=${approver}`);
process.exit(0);
