# Agent Instructions — gpu-driver-container

This file applies to all AI coding agents working in this repository
(Claude Code, Codex, Cursor, Copilot, and compatible hosts).

Read this file before starting any task.

## Repository map

This repo ships GPU driver container images for multiple OS targets:

| Directory | OS |
|---|---|
| `ubuntu22.04/` | Ubuntu 22.04 |
| `ubuntu24.04/` | Ubuntu 24.04 |
| `ubuntu26.04/` | Ubuntu 26.04 |
| `rhel8/` | RHEL 8 / Rocky 8 / AlmaLinux 8 |
| `rhel9/` | RHEL 9 / Rocky 9 / AlmaLinux 9 |
| `rhel10/` | RHEL 10 |
| `vgpu/` | vGPU (host driver) |
| `vgpu-manager/` | vGPU Manager |
| `base/` | Common base image layers |
| `tests/` | Test scripts |
| `ci/` | CI workflow helpers |

The distro directories share the same driver install logic expressed
independently per OS. The same pattern or bug often appears in multiple
directories.

## Hard rules for agents

### 1. Check for duplicates before opening any PR

Run these searches before opening a PR:

```bash
gh pr list --repo NVIDIA/gpu-driver-container --state open --search "<file or function name>"
gh pr list --repo NVIDIA/gpu-driver-container --state open --search "<short topic keywords>"
gh issue list --repo NVIDIA/gpu-driver-container --state open --search "<short topic keywords>"
```

If an open PR already addresses the same fix: **stop, do not open another.**
If your approach differs materially, explain the difference in the existing
issue or PR thread instead of opening a new one.

### 2. Open an issue before submitting more than one PR on the same topic

If you find the same bug or pattern in five or more places, open one GitHub
issue first. Describe the pattern and your proposed fix. Wait for a
maintainer response before opening any PR. This prevents flooding CI with
work the team has not yet approved.

### 3. Never open more than three PRs in a single session

Each PR triggers a full CI run. Submitting many PRs at once blocks CI for
every other contributor. If you have many fixes, open an issue listing
them and let a maintainer prioritize.

### 4. One PR per root cause — not one PR per file

When the same bug exists in multiple distro directories, fix all instances
in a single PR. Title it around the root cause, not a single file:

- **Good:** `fix: set -e suppresses command-substitution exit codes (all distros)`
- **Avoid:** ten separate PRs — one per `nvidia-driver` file — for the same
  one-liner change

Apply cross-distro fixes consistently. If a fix is needed in ubuntu22.04,
check ubuntu24.04, rhel8, rhel9, rhel10, and ubuntu26.04 before opening
your PR.

### 5. Separate correctness fixes from cosmetic changes

Put style-only changes (variable naming, deprecated test syntax, whitespace)
in their own PR. Do not bundle cosmetic changes with bug fixes — reviewers
triage correctness issues first and cosmetic noise slows the queue.

### 6. Every PR must link to an issue

Include `Fixes #NNN` or `Related to #NNN` in the PR body. If no issue
exists, open one first (see rule 2). PRs without an issue link may be
closed without review.

### 7. Submit PRs as drafts

Use `gh pr create --draft`. Mark a PR ready for review only after you have
run local tests and confirmed there are no conflicts with other open PRs.

### 8. Write tests that execute the code

A test that greps for the absence of old text is a linter check, not a
regression test. Tests belong in `tests/` and must invoke the function or
code path being fixed and verify correct behavior. A test that would pass
on the unchanged code is not useful.

### 9. Never push or create a PR without explicit human approval

Commit locally and stop. Do not run `git push` or `gh pr create` unless
the user has explicitly asked you to publish in this turn. "Fix the bug"
is not approval to publish.

### 10. Disclose AI assistance

PR descriptions for AI-assisted work must include:

- A clear statement that AI assistance was used.
- The test commands you ran and their results.
- Why this PR does not duplicate an existing open PR.

## Fail-closed behavior

If any of these conditions is true, **stop and report** instead of
proceeding:

- An open PR already exists for the same fix or file.
- The change touches more than three distro directories and no issue has
  been filed and acknowledged by a maintainer.
- The fix is cosmetic only (no behavior change).
- You cannot run any test to confirm the fix works.

Return a short explanation of what you found and what the maintainer
should do next.

## Contribution workflow

1. File an issue describing the problem and proposed fix.
2. Wait for maintainer acknowledgment.
3. Create a feature branch.
4. Fix the root cause across all affected distro directories in one commit.
5. Add or update a test in `tests/` that executes the fixed code path.
6. Run `make test` or the closest available test target.
7. Open a **draft** PR with `Fixes #NNN` in the body.
8. Mark the PR ready for review only after checks pass.

See [CONTRIBUTING.md](CONTRIBUTING.md) for DCO sign-off requirements and
the full PR guidelines.

## Testing

Tests live in `tests/`. Run them before opening a PR:

```bash
# Run all tests (from repo root)
make test

# Or run a specific test script directly
bash tests/<test-script>.sh
```

Tests must execute the code path being validated. Static pattern checks
(grep for old text) are not sufficient as regression tests.

## CI rate courtesy

Each open PR holds a CI slot. The CI system is shared. Do not open PRs
speculatively or in bulk. Every PR should have a clear motivation, an
issue reference, and a human who can defend it in review.
