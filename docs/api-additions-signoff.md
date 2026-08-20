# Public API Additions: How the Signoff Gate Works

Every symbol marked `public` in this SDK is a long-term support commitment: once it ships in a
release, external developers can build on it and we cannot remove or change it without a breaking
release. The `api-additions-signoff` check makes each addition to the public surface a deliberate,
human-acknowledged decision — the same way `major-release-signoff` gates breaking changes.

This guide explains what to expect from the check and how to work with it, whether you are adding
API, reviewing a PR, or maintaining the gate itself.

## Adding or changing public API (PR authors)

1. Open your PR as usual. If it touches `Sources/**` or `Package.swift`, CI diffs the public API
   surface between your PR's merge-base and head (`swift-api-digester` dumps compared by
   `scripts/report-api-additions.py`).
2. If your PR adds public symbols, a bot comment appears listing every new symbol grouped by source
   folder, and the `api-additions-signoff` commit status fails until a maintainer acknowledges.
3. Check the list. **If an addition is accidental** (a helper left `public` instead of `internal`),
   push a fix marking it `internal` — the comment updates to "gate cleared" and the status flips to
   success automatically. No acknowledgment needed.
4. **If the additions are intentional**, nothing more is required from you; a maintainer other than
   you clears the gate (below). You cannot acknowledge your own PR.

PRs that add no public symbols see nothing: no comment, status passes silently.

Keep in mind before marking anything `public`:

- Prefer `internal` unless external developers genuinely need the symbol.
- Synthesized declarations (e.g. `==` on `Equatable` structs) appear in the list under
  "Synthesized or associated declarations" — they are secondary, not separate commitments.
- The list is scoped to *your PR's* additions only (diffed against the merge-base, not `main`
  tip), so unrelated changes merged to `main` never show up in it.

## Acknowledging additions (reviewers / maintainers)

The bot comment includes a copy-paste-ready reply block with the acknowledgment phrase and the
current report hash. To clear the gate:

1. Verify each listed symbol is an intentional, supportable addition. This is the entire point of
   the gate — treat it as "are we ready to support this forever?", not a formality.
2. Reply with the copy-paste block, unmodified. Requirements enforced by the gate:
   - You must have write access to the repo.
   - You must not be the PR author.
   - The reply must quote the report hash from the current comment — a new push that changes the
     addition set changes the hash and invalidates prior acknowledgments.
3. The status flips to success and records who acknowledged. Deleting the acknowledgment comment
   re-fails the status.

If the additions should not ship, request changes as usual; the failing status stands until the
symbols are removed or acknowledged.

### PRs that modify the gate's own tooling

If a PR touches the signoff workflows or their scripts, the symbol list was produced by that PR's
own modified tooling and cannot be trusted. The bot comment carries an explicit warning in that
case, and acknowledgment is required regardless of the reported count. **Verify against the
`Sources/` diff directly, not the rendered list.**

### Fork PRs

External contributions are gated identically. Detection runs unprivileged on the fork's code; all
comment and status writes run from trusted default-branch code. Nothing extra is required from the
contributor — a maintainer acknowledges the same way.

## What the gate does not do

- It is not a hard security control: admins can merge past the failing check. The comment and
  status history still record that it was bypassed.
- It does not classify additions by impact — every new public symbol is listed flat; judgment is
  the reviewer's.
- It does not gate breaking changes — those remain covered by `api-stability.yml` and
  `major-release-signoff.yml`.

## Running detection locally

Simulate the detect step on a Mac before pushing:

```sh
scripts/check-api-stability.sh dump /tmp/dump-base     # at the base commit
# check out your branch
scripts/check-api-stability.sh dump /tmp/dump-head
scripts/check-api-stability.sh report /tmp/dump-base /tmp/dump-head --count-file /tmp/n
```

## Maintaining the gate

Pieces and their responsibilities:

- `.github/workflows/api-additions-signoff.yml` — **detect** (unprivileged, `contents: read`):
  runs on `pull_request` for every PR including forks, builds and diffs the API surface, uploads
  report + count + hash as an artifact.
- `.github/workflows/api-additions-signoff-gate.yml` — **gate** (privileged): handles both
  `workflow_run` completion and `issue_comment` re-evaluation from default-branch code; downloads
  the artifact, searches for acknowledgment, upserts the PR comment, posts the commit status.
- `scripts/report-api-additions.py` — computes the addition set and renders the report. The
  rendered text is hashed for acknowledgment binding, so **formatting is load-bearing**.
- `scripts/find-api-additions-comment.sh` — sole reader/writer of the marker-line format
  (`<!-- api-additions-signoff head=<sha> hash=<12-hex> count=<n> tooling=<0|1> -->`), the
  `issue_comment` path's only state between runs.
- `scripts/find-api-additions-acknowledgment.sh` — acknowledgment matching and permission
  verification; `--print-phrase` is the single source of the phrase. Keep in sync with the inline
  matcher in `major-release-signoff.yml` (reciprocal notes in both).

Trust boundary rules when changing the gate — the artifact is untrusted fork output:

- Identity (head SHA, PR number, PR author) comes only from the trusted `workflow_run` payload
  and API lookups, never from the artifact.
- `count=` / `hash=` from `meta.txt` are strictly validated; malformed input fails closed.
- `report.txt` is sanitized (backticks neutralized, size-capped) before embedding in the comment.
- Never execute PR-controlled code in the gate workflow — that is why tooling-touching PRs get the
  warning path instead of trusted recomputation.
- All gate evaluations share one serialized concurrency queue with cancel-in-progress off; the
  two trigger types cannot share a per-PR key, and parallel runs could let a stale evaluation
  overwrite a newer status.
