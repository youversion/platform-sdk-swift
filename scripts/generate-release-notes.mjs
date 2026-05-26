#!/usr/bin/env node
// Generate release notes for a chosen version by calling
// `@semantic-release/release-notes-generator` directly, with no
// semantic-release lifecycle around it.
//
// The semantic-release CLI couples notes generation to the rest of the
// release lifecycle (auth verification, plugin orchestration, branch
// detection). That coupling is what made `--dry-run` fragile on PRs and
// what made overriding a calculated version impossible. By calling the
// notes-generator module as a library, this script asks one focused
// question: "given these commits, what changelog entry should ship?"
//
// Output (stdout): the changelog markdown for the chosen version. No
// surrounding noise — the caller pipes it directly into CHANGELOG.md
// and into `gh release create --notes-file`.
//
// Usage:
//   node scripts/generate-release-notes.mjs \
//     --base <last-tag-or-sha> \
//     --head <head-sha> \
//     --version <semver>

import { readFileSync } from "node:fs";
import { execSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import { format } from "node:util";
import { generateNotes } from "@semantic-release/release-notes-generator";

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

// Read the notes-generator plugin config from .releaserc.json so the
// preset (conventionalcommits) and any inline overrides stay in lockstep
// with the rest of the release tooling.
function readNotesGeneratorConfig() {
  const releasercPath = resolve(REPO_ROOT, ".releaserc.json");
  const releaserc = JSON.parse(readFileSync(releasercPath, "utf8"));
  const entry = releaserc.plugins.find(
    (p) => (Array.isArray(p) ? p[0] : p) === "@semantic-release/release-notes-generator"
  );
  if (!entry) {
    throw new Error(
      `@semantic-release/release-notes-generator not configured in ${releasercPath}`
    );
  }
  return Array.isArray(entry) ? entry[1] : {};
}

function readRepositoryUrl() {
  const pkgPath = resolve(REPO_ROOT, "package.json");
  const pkg = JSON.parse(readFileSync(pkgPath, "utf8"));
  const repo = pkg?.repository;
  const url = typeof repo === "string" ? repo : repo?.url;
  if (!url) {
    throw new Error(`No repository.url in ${pkgPath}`);
  }
  return url;
}

// Same ASCII-RS/US delimiter trick as preview-release.mjs so commit
// bodies with arbitrary whitespace/quotes don't break parsing.
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

function resolveSha(rev) {
  return execSync(`git rev-parse ${JSON.stringify(rev)}`, {
    cwd: REPO_ROOT,
    encoding: "utf8",
  }).trim();
}

// release-notes-generator uses signale-style printf logging; route to
// stderr via util.format so stdout is reserved for the rendered notes.
const logger = {
  log: (...a) => console.error("[notes]", format(...a)),
  info: (...a) => console.error("[notes]", format(...a)),
  warn: (...a) => console.error("[notes]", format(...a)),
  error: (...a) => console.error("[notes]", format(...a)),
  success: (...a) => console.error("[notes]", format(...a)),
};

async function main() {
  const args = parseArgs(process.argv.slice(2));
  for (const required of ["base", "head", "version"]) {
    if (!args[required]) {
      console.error(`Missing required argument: --${required}`);
      console.error(
        "Usage: generate-release-notes.mjs --base <ref> --head <sha> --version <semver>"
      );
      process.exit(2);
    }
  }

  const pluginConfig = readNotesGeneratorConfig();
  const repositoryUrl = readRepositoryUrl();
  const commits = getCommits(args.base, args.head);
  const lastReleaseSha = resolveSha(args.base);
  const headSha = resolveSha(args.head);

  const notes = await generateNotes(pluginConfig, {
    commits,
    lastRelease: {
      gitHead: lastReleaseSha,
      gitTag: args.base,
      version: args.base, // Notes generator only uses this for the "compare" link label
    },
    nextRelease: {
      gitHead: headSha,
      gitTag: args.version,
      version: args.version,
    },
    options: { repositoryUrl },
    cwd: REPO_ROOT,
    logger,
  });

  process.stdout.write(notes);
  if (!notes.endsWith("\n")) process.stdout.write("\n");
}

main().catch((err) => {
  console.error(err?.stack || String(err));
  process.exit(1);
});
