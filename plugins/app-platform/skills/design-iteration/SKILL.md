---
name: design-iteration
description: Track a new design handoff zip as a diffable iteration in this project's design-archive repo and open a PR whose diff is the build spec. Use when a design handoff zip arrives or the user says "new design", "design iteration", "add this design", "track this design", "diff the design", "what changed in the design".
---

# Design Iteration Tracker

Designs arrive as handoff zips. Instead of eyeballing a whole new bundle, every
iteration is committed to a dedicated git repo so `git diff` between iterations is
the exact, reviewable spec to build against. **Nothing here is project-specific** —
the archive location comes from `.claude/project.yml`.

## Step 0 — Load the manifest

Read `.claude/project.yml` → `design`:

- `design.archive_dir` — local path to this project's design-archive git repo
  (e.g. `~/git/github/<project>/claude-design-archive`). Expand `~`/`$HOME`.
- `design.app_dir` — which service the design maps to (e.g. `dashboard`), for the
  "what to build" mapping below.

If there is no `design` block, tell the user the project hasn't been set up for
design iterations and stop. (Setup = a git repo at `archive_dir` with a `project/`
folder; `uploads/ screenshots/ *.thumbnail` gitignored.)

## When the user gives you a new design zip

Run the helper, passing the **archive dir** (from the manifest), the zip path, and
an optional one-line summary:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/design-iteration/add-iteration.sh" \
  "<design.archive_dir>" "/path/to/new-design.zip" "short summary"
```

It will: sync `main` → create branch `design/iteration-N` → unzip and replace the
code files under `project/` (auto-detecting nested vs flat zips) → commit (commit
date set to the zip's timestamp) → push → open a PR, printing the PR URL. If the zip
is identical to the current iteration it exits cleanly without a commit.

## Then: review the diff = the build spec

```bash
# Full delta of the new iteration vs the previous one:
git -C "<design.archive_dir>" diff main..design/iteration-N -- project/
# Just the file list / stat first to scope it:
git -C "<design.archive_dir>" diff --stat main..design/iteration-N -- project/
```

Read the diff before assuming scope — small zips often hide big logic changes in
one file (and vice-versa). Map each changed design file to the implementation in
`<design.app_dir>` (e.g. `app.jsx`→sidebar/routing, `styles.css`→global styles,
component files→shared UI). The exact mapping is project-specific; consult
`CLAUDE.md` if the project documents one.

## Merging + tagging the iteration

The PR is the user's to merge (they own the design baseline). After they merge — or
if they ask you to — from the archive repo:

```bash
gh pr merge <branch> --squash --delete-branch
git -C "<design.archive_dir>" checkout main && git -C "<design.archive_dir>" pull --ff-only
git -C "<design.archive_dir>" tag iteration-N main && git -C "<design.archive_dir>" push origin iteration-N
```

Once merged, `main` is the current design baseline and the next zip diffs against
it. Each iteration is tagged `iteration-N`, so `git diff iteration-6 iteration-7 --
project/` shows any pair's delta. The script also copies the source zip into `zips/`
(the heavy-artifact store) as part of the iteration commit.

## Notes
- Requires `gh` authenticated for the project's GitHub org. The archive repo must
  already exist locally as a git repo — do not recreate it.
- This is read/normalize/commit of design prototypes — **never run** these design
  files; they're specs, not app code. Build the equivalent in the app.
