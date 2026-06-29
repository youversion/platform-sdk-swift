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
//   { current, next, release_type, is_major, commit_count, prerelease_next }
// `release_type` is one of `"major" | "minor" | "patch" | null`.
// `prerelease_next` is the next pre-release candidate when `--prerelease
// <channel>` is supplied (channel ∈ alpha|beta|rc), otherwise null.
//
// Usage:
//   node scripts/preview-release.mjs --base <sha> --head <sha>
//   node scripts/preview-release.mjs --base <sha> --head <sha> --prerelease beta
//   node scripts/preview-release.mjs --base <sha> --head <sha> --prerelease rc --current 5.3.0-beta.1
//
// `--current <version>` overrides the base version (default: latest git tag).

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
  // `--current` pins the base version explicitly. Defaults to the latest tag.
  // Useful on a pre-release branch (where `git describe` may not resolve the
  // in-flight pre-release tag) and makes the channel math deterministically
  // testable without manufacturing git tags.
  const current = args.current || getCurrentVersion();

  const releaseType = await analyzeCommits(pluginConfig, {
    commits,
    logger,
    cwd: REPO_ROOT,
  });

  const next = releaseType ? semver.inc(current, releaseType) : current;

  // Channel-aware pre-release candidate. Two regimes, per SemVer 2.0.0 §9 —
  // a pre-release's normal version (MAJOR.MINOR.PATCH) is the version it is a
  // pre-release *of*, so the alpha → beta → rc sequence is a series of
  // candidates for ONE fixed target version line:
  //
  //   - `current` is STABLE → start a fresh pre-release line. `pre<type>`
  //     (premajor/preminor/prepatch) applies the core bump that moves us onto
  //     the new line: inc('5.2.3','preminor','beta') → 5.3.0-beta.0.
  //
  //   - `current` is ALREADY a pre-release of target X.Y.Z → the core bump is
  //     already baked in; re-running `pre<type>` double-bumps it
  //     (inc('5.3.0-beta.1','preminor','rc') → 5.4.0-rc.0, WRONG — jumps off
  //     the 5.3.0 line). Advance only the pre-release tail with `prerelease`,
  //     which keeps the core fixed and resets the counter to 0 when the
  //     channel identifier changes:
  //       inc('5.3.0-beta.1','prerelease','rc')  → 5.3.0-rc.0   (channel switch)
  //       inc('5.3.0-beta.1','prerelease','beta') → 5.3.0-beta.2 (same channel)
  //
  // Stages may only advance (alpha → beta → rc). `semver.inc` will silently
  // compute a BACKWARD step (inc('5.3.0-rc.1','prerelease','beta') →
  // 5.3.0-beta.0, which is *lower* than current), so we guard channel ordering
  // ourselves and reject rather than emit a version release-validate.mjs would
  // later refuse anyway.
  //
  // When the analyzer scores no bump but a channel was requested (an additive
  // feature floated as a pre-release), default the (stable-only) releaseType
  // to 'minor'.
  const VALID_CHANNELS = ["alpha", "beta", "rc"]; // index = precedence rank
  let prereleaseNext = null;
  if (args.prerelease != null) {
    const channel = args.prerelease;
    if (!VALID_CHANNELS.includes(channel)) {
      console.error(
        `Invalid --prerelease channel '${channel}'. Expected one of: ${VALID_CHANNELS.join(", ")}`
      );
      process.exit(2);
    }
    const currentPre = semver.prerelease(current); // e.g. ['beta', 1] or null
    if (!currentPre) {
      // Stable → open a fresh pre-release line (the core bump is correct here).
      const effectiveType = releaseType || "minor";
      prereleaseNext = semver.inc(current, "pre" + effectiveType, channel);
    } else {
      // Already a pre-release: core is frozen, only the tail advances.
      const currentChannel = String(currentPre[0]);
      const rank = (c) => VALID_CHANNELS.indexOf(c);
      // rank(currentChannel) is -1 for a non-standard identifier (e.g. a
      // hand-cut `-foo.1`); any valid `channel` has rank >= 0 > -1, so such a
      // base is never falsely rejected — it falls through to `prerelease`.
      if (rank(channel) < rank(currentChannel)) {
        console.error(
          `Refusing backward pre-release transition: current is '${current}' ` +
          `(${currentChannel}) but requested channel '${channel}' has lower ` +
          `precedence. Pre-release stages may only advance: alpha → beta → rc.`
        );
        process.exit(3);
      }
      prereleaseNext = semver.inc(current, "prerelease", channel);
    }
  }

  process.stdout.write(
    JSON.stringify({
      current,
      next,
      release_type: releaseType,
      is_major: releaseType === "major",
      commit_count: commits.length,
      prerelease_next: prereleaseNext,
    }) + "\n"
  );
}

main().catch((err) => {
  console.error(err?.stack || String(err));
  process.exit(1);
});
