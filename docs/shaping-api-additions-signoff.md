# API Additions Signoff Gate — Shaping Document

| Field    | Value                                          |
|----------|------------------------------------------------|
| Date     | 2026-08-11                                     |
| Status   | Draft                                          |
| Team     | Platform SDK (Swift)                           |
| Author   | Jared Hightower                                |
| Audience | All (Product / Engineering / SDK stakeholders) |

---

## Problem

Every symbol the SDK marks `public` is a support commitment: once it ships in a release, external
developers can build on it and we cannot remove or change it without a breaking release. Today a PR
can add new public API and merge with nobody explicitly confirming the addition was intentional —
reviewers see the code diff, but nothing forces the question "are we ready to support this
forever?" The repo already blocks *breaking* changes behind a human signoff
(`major-release-signoff.yml`), but *additions* — the more common way accidental commitments happen —
have no equivalent gate.

---

## Open Questions

1. **Acknowledgment strictness** — Should the acknowledger be required to be someone other than the
   PR author (matching the breaking-change gate), or is author self-acknowledgment enough for
   additions? Second pair of eyes is safer; solo-maintainer PRs would stall. *Owner: Engineering lead*
2. **Merge blocking** — Should the gate be a hard merge block (branch protection required check) or
   a visible-but-advisory failing check for an initial trial period? *Owner: Engineering lead*
3. **Fork contributions** — This is a public repo. Should the gate run on PRs from external forks
   (requires elevated-token handling), or only on PRs from branches in this repo for v1?
   *Owner: Engineering lead*
4. **Rubber-stamp review** — After the gate has run for ~2 months, who audits whether
   acknowledgments are meaningful (e.g., sampling acknowledged symbols that later got walked back)?
   *Owner: SDK maintainers*

---

## Why It Matters

- **Accidental API commitments are permanent.** A helper left `public` instead of `internal` ships
  in the next release and must be supported until the next major version. Catching it pre-merge
  costs one comment; catching it post-release costs a deprecation cycle.
- **The ticket's acceptance criterion is explicit:** a human must be able to verify the output of
  `scripts/check-api-stability.sh additions` before a release goes out. Today that script exists
  but nothing in the process forces anyone to look at it.
- **Reviewer visibility gap:** new public symbols are scattered across a code diff; reviewers have
  no consolidated view of "this PR grows the public surface by N symbols."
- **Parity with existing practice:** breaking changes already require explicit human signoff in
  this repo. Additions are the same class of commitment at lower severity — same treatment, lighter
  weight.

---

## Target Experience

### PR author

Pushes a PR that adds `public func foo()`. Within minutes, a bot comment appears on the PR:

> **📣 This PR adds 3 public API symbols** — merging commits the SDK to supporting them.
> *(grouped list by source folder, same format as `check-api-stability.sh additions`)*
> To proceed, a maintainer must reply with the acknowledgment phrase below.

A commit status `api-additions-signoff` shows as failing until acknowledgment. If the author
realizes an addition was accidental, they push a fix marking it `internal`; the comment updates to
"no public additions — gate cleared" and the status flips to success automatically.

### Reviewer / maintainer

Sees the consolidated symbol list without hunting through the diff. If the additions are
intentional, copy-pastes the ready-made acknowledgment reply. The status flips to success and
records who acknowledged. If not intentional, requests changes as usual.

### What stays the same

- The existing breaking-change check (`api-stability.yml`) and major-release signoff gate are
  untouched — additions and breakages remain separate signals.
- PRs that touch no public API see nothing: no comment, status passes silently.

### Explicitly deferred

- No change to the release pipeline itself — verification happens at PR time, which is earlier and
  per-change rather than batched at release time.
- No automated filtering of "impactful vs. harmless" additions — every new public symbol is listed.

---

## Solution

### Approach

Clone the repo's proven `major-release-signoff.yml` workflow — comment upsert, acknowledgment
matching, permission verification, commit status — and swap its trigger: instead of detecting a
breaking-change commit message, it detects new public symbols by diffing the API surface between
the PR's merge-base and head using the existing `swift-api-digester` dump machinery and
`report-api-additions.py`. Per-PR diffing (not diff-against-committed-baseline) keeps the comment
scoped to *this PR's* additions, avoiding the cumulative-noise failure mode.

### Diagram

```mermaid
flowchart TD
    A[PR opened or updated] --> B[Build & dump public API<br/>at merge-base and at head]
    B --> C{New public symbols<br/>in this PR?}
    C -- no --> D[Status: success<br/>no comment / clear old comment]
    C -- yes --> E[Upsert PR comment:<br/>symbol list + acknowledgment phrase]
    E --> F{Qualifying acknowledgment<br/>comment found?}
    F -- no --> G[Status: failure<br/>merge blocked]
    F -- yes --> H[Status: success<br/>records acknowledger]
    I[Acknowledgment comment<br/>posted / edited / deleted] --> F
```

*One workflow: detect per-PR public API additions, surface them in one comment, gate merge on a
human acknowledgment, and clear automatically when additions are removed.*

### Implementation Notes

#### Detection (per-PR API diff)

- Reuse `dump_module` from `scripts/check-api-stability.sh`: `swift build -c release` +
  `xcrun swift-api-digester -dump-sdk` for the three modules, once at the merge-base commit and
  once at head.
- Feed both dump directories to `scripts/report-api-additions.py` (already computes set-difference
  and groups by source folder). Small change: accept two dump dirs instead of baseline-dir +
  current-dir semantics if needed; output both human text and a machine-readable count.
- Runner: `macos-26` with `XCODE_VERSION: latest-stable`, matching `api-stability.yml`.
- Gate the expensive build behind a `paths` filter (`Sources/**`, `Package.swift`) so docs-only
  PRs skip it entirely.

#### Comment and acknowledgment mechanics (lifted from major-release-signoff.yml)

- Marker comment `<!-- api-additions-signoff -->`, upserted (PATCH existing, never spam).
- Comment body: one orientation line, the grouped symbol list, and a copy-paste-ready reply block
  containing a verbatim acknowledgment phrase, e.g. *"I confirm these public API additions are
  intentional and we are committing to support them."*
- Acknowledgment matching: same normalization (strip quote markers, collapse whitespace), bot
  accounts skipped, permission lookup fail-closed, permission cache — all verbatim from the
  breaking-change gate (hardened in af9f8e5).
- Triggers: `pull_request` (opened, synchronize, reopened) + `issue_comment` (created, edited,
  deleted) so the gate re-evaluates when acknowledgments appear or disappear.
- Commit status context `api-additions-signoff`: failure with "N public additions awaiting
  acknowledgment", success with "acknowledged by @user" or "no public API additions".
- Concurrency group per PR, cancel-in-progress.

#### Edge cases

- **Additions redacted after acknowledgment:** a new push re-runs detection; if additions are gone,
  status succeeds and the comment is updated to inactive. If a *different* set of additions
  appears, the prior acknowledgment must not carry over — include a hash of the symbol list in the
  comment and require the acknowledgment to postdate the latest symbol-list change.
- **Base branch moves:** diff against the merge-base of head and `main`, not `main` tip, so
  unrelated additions merged to main don't leak into the PR's list.
- **Digester noise:** synthesized declarations (e.g., `==` on Equatable structs) appear in
  additions output; keep the existing "Synthesized or associated declarations" grouping so
  reviewers see them as secondary, not as separate commitments.
- **Missing baseline / build failure:** fail the status with a clear message; never silently pass.

#### v1 constraints

- Runs on same-repo branches only if fork-token handling is deferred (Open Question 3).
- No impact analysis or symbol classification — flat list, human judgment.
- English-only comment text.

---

## Testing Plan

In order of value:

1. **Local dump run (first, cheap):** `scripts/check-api-stability.sh dump /tmp/api-dump` on a Mac
   verifies the new mode against the real build. The whole detect step can be simulated locally:
   dump at `main`, check out a branch with a test symbol, dump again, then
   `scripts/check-api-stability.sh report /tmp/dump-a /tmp/dump-b --count-file /tmp/n`.
2. **Stacked scratch PR (real end-to-end for `detect`, pre-merge):** branch off the implementation
   branch, add a dummy `public func gateTest()` in `Sources/YouVersionPlatformCore/`, and open a PR
   **with the implementation branch as base, not `main`**. `pull_request` workflows run from the
   merge ref, so the new workflow executes with the paths filter matching. Expected: bot comment
   with symbol list + hash, failing `api-additions-signoff` status. Then a write-access collaborator
   *other than the author* (non-author rule) pastes the acknowledgment block, an empty commit
   (`git commit --allow-empty`) re-triggers detect, and the status flips to success. Marking the
   symbol `internal` and pushing should flip the comment to "gate cleared". Close the scratch PR and
   delete the branch afterward.
3. **Post-merge only — the `issue_comment` path:** `issue_comment` workflows always run from the
   *default branch*, so the `acknowledge` job (comment posted → status flips without a push) cannot
   be tested before merge. After merge, repeat the scratch PR against `main` once to verify it.

Known limitations: step 2 covers everything except comment-triggered re-evaluation, which is
inherently untestable pre-merge; `act` does not help (no macOS runner support). The implementation
PR itself does not trigger the gate — it touches no `Sources/**` or `Package.swift`, so the paths
filter skips it.

---

## Risks

- **Reviewer rubber-stamping** — the gate's value decays if acknowledgment becomes a reflexive
  copy-paste. Research on review-bot fatigue says keep the comment short, scoped to this PR only,
  and silent when nothing changed. Mitigation: per-PR scoping (built in), and a periodic audit
  (Open Question 4).
- **CI cost and latency** — two release builds per API-touching PR on macOS runners adds minutes
  and runner spend. Mitigation: `paths` filter skips non-source PRs; potential future optimization
  is sharing the build with the existing `api-stability.yml` job.
- **Fork PRs can't clear the gate** — external contributors' workflow tokens can't post statuses or
  comments without `pull_request_target` handling; a fork PR would sit blocked. Mitigation: follow
  the af9f8e5 hardening pattern already used by the breaking-change gate, or scope v1 to same-repo
  branches and decide fork handling explicitly.
- **Gate bypass via admin merge** — admins can merge past a failing required check. Accepted: the
  gate is a forcing function for attention, not a security control; the audit trail (comment +
  status history) still records that the gate was bypassed.
- **Acknowledgment staleness** — approving symbols that later change within the same PR would leave
  a stale approval. Mitigation: symbol-list hash + acknowledgment-must-postdate rule (see Edge
  cases).

---

## Open Questions — Detail

| # | Question | Owner | Status |
|---|----------|-------|--------|
| 1 | Must the acknowledger be a non-author (matching the breaking-change gate), or is author self-acknowledgment acceptable for additions? | Engineering lead | Open |
| 2 | Hard merge block via branch protection from day one, or advisory failing check during a trial period? | Engineering lead | Open |
| 3 | Support fork PRs in v1 (requires elevated-token handling per af9f8e5 pattern) or same-repo branches only? | Engineering lead | Open |
| 4 | Who audits acknowledgment quality after ~2 months, and what signal triggers tightening or loosening the gate? | SDK maintainers | Open |

---

## Appendix

- Ticket: "swift: api additions should be confirmed by humans during the release process" —
  acceptance criterion: a method exists that displays `scripts/check-api-stability.sh additions`
  output for human verification before release.
- Existing in-repo prior art: `.github/workflows/major-release-signoff.yml` (comment-upsert +
  acknowledgment gate, hardened in commit af9f8e5), `.github/workflows/api-stability.yml`
  (breaking-change check on macos-26), `scripts/check-api-stability.sh`,
  `scripts/report-api-additions.py`, `.github/workflows/coverage-comment.yml` (workflow_run
  comment pattern for fork PRs).
- Research inputs (arXiv, read 2026-08-11): 2110.07889 (most flagged API changes affect no real
  client — scope lists per-PR to avoid fatigue), 2607.24601 (moderate explanation maximizes
  reviewer agreement; exhaustive dumps reduce sign-off), 2507.09637 (give context/rationale before
  the acknowledgment ask), 2309.02894 (keep additions and breakage gates separate),
  2601.19065 (shrinking accidental public surface upstream quiets the gate).
- Alternatives considered and not chosen: committed-baseline + CODEOWNERS on `.api-baseline/`
  (durable git record, but noisy machine-generated diffs and workflow change for all
  contributors — candidate for phase 2); Danger/Danger-Swift (new dependency for what existing
  pattern already does); client-impact-filtered diffing (needs a client corpus an SDK pre-release
  doesn't have).
