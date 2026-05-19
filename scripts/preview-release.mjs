#!/usr/bin/env node
// Compute the release type and next version for a PR by calling
// `@semantic-release/commit-analyzer` directly. Avoids the full
// `semantic-release --dry-run` lifecycle, which on a `pull_request` event
// fails at the core `verifyAuth()` step (`git push --dry-run`) because the
// PR-event `GITHUB_TOKEN` has `contents: read` only. That failure aborts
// before the analyzer runs and produces a silent false-negative "no bump"
// preview — the same fail-open class that hid the major bump on the squash
// of PR #117.
//
// Output (stdout): one line of JSON:
//   { current, next, release_type, is_major, commit_count }
// `release_type` is one of `"major" | "minor" | "patch" | null`.
//
// Usage:
//   node scripts/preview-release.mjs --base <sha> --head <sha>

import { readFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { format } from "node:util";
import semver from "semver";
import { analyzeCommits } from "@semantic-release/commit-analyzer";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i]?.replace(/^--/, "");
    if (!key) continue;
    out[key] = argv[i + 1];
  }
  return out;
}

// Read the same plugin config that production uses on `main`, so the
// preview applies identical semver-inference rules (preset, releaseRules,
// parserOpts, etc.). If the config shape ever changes, the preview tracks
// it automatically.
function readCommitAnalyzerConfig() {
  const releasercPath = resolve(REPO_ROOT, ".releaserc.json");
  const releaserc = JSON.parse(readFileSync(releasercPath, "utf8"));
  const entry = releaserc.plugins.find(
    (p) => (Array.isArray(p) ? p[0] : p) === "@semantic-release/commit-analyzer"
  );
  if (!entry) {
    throw new Error(
      `@semantic-release/commit-analyzer not configured in ${releasercPath}`
    );
  }
  return Array.isArray(entry) ? entry[1] : {};
}

// Collect commits in `base..head` as `{hash, message}` records. Use ASCII
// US (0x1f) between fields and RS (0x1e) between records so commit bodies
// with arbitrary whitespace, quotes, and Unicode can't break parsing.
function getCommits(base, head) {
  const fmt = "%H%x1f%B%x1e";
  const out = execSync(`git log --reverse --format=${JSON.stringify(fmt)} ${base}..${head}`, {
    cwd: REPO_ROOT,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  return out
    .split("\x1e")
    .map((rec) => rec.replace(/^\n+/, ""))
    .filter(Boolean)
    .map((rec) => {
      const [hash, message] = rec.split("\x1f");
      return { hash: (hash ?? "").trim(), message: (message ?? "").trim() };
    });
}

function getCurrentVersion() {
  try {
    const tag = execSync("git describe --tags --abbrev=0", {
      cwd: REPO_ROOT,
      encoding: "utf8",
    }).trim();
    // Strip leading `v` so the caller always gets a bare semver string
    // (e.g. "1.2.3"). The workflow already prepends `v` in the display
    // strings, and semver.inc() also returns without a prefix — keeping
    // both in sync avoids a `vv1.2.3` double-prefix in PR comments.
    return tag.replace(/^v/, "") || "0.0.0";
  } catch {
    return "0.0.0";
  }
}

// commit-analyzer expects a signale-shaped logger and calls methods with
// printf-style format strings (e.g. `log("Analyzing commit: %s", msg)`).
// Route everything through util.format so the substitutions actually
// happen, and to stderr so stdout stays clean for the JSON payload.
const logger = {
  log: (...a) => console.error("[analyzer]", format(...a)),
  info: (...a) => console.error("[analyzer]", format(...a)),
  warn: (...a) => console.error("[analyzer]", format(...a)),
  error: (...a) => console.error("[analyzer]", format(...a)),
  success: (...a) => console.error("[analyzer]", format(...a)),
};

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!args.base || !args.head) {
    console.error("Usage: preview-release.mjs --base <sha> --head <sha>");
    process.exit(2);
  }

  const pluginConfig = readCommitAnalyzerConfig();
  const commits = getCommits(args.base, args.head);
  const current = getCurrentVersion();

  const releaseType = await analyzeCommits(pluginConfig, {
    commits,
    logger,
    cwd: REPO_ROOT,
  });

  const next = releaseType ? semver.inc(current, releaseType) : current;

  process.stdout.write(
    JSON.stringify({
      current,
      next,
      release_type: releaseType,
      is_major: releaseType === "major",
      commit_count: commits.length,
    }) + "\n"
  );
}

main().catch((err) => {
  console.error(err?.stack || String(err));
  process.exit(1);
});
