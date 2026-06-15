---
name: github-issues
description: Creating and managing GitHub issues for this project with the gh CLI. Use when creating issues, adding comments, closing, or listing issues. Triggers on "gh issue", "github issue", "create issue", "open an issue", "file a bug".
---

# GitHub Issues

Generic issue workflow driven by the project manifest. **Nothing here is
project-specific** — every name comes from `.claude/project.yml`.

## Step 0 — Load the manifest (always do this first)

Read `.claude/project.yml` and pull:

- `github.org` and `github.repos` — the repos you may target.
- `admin_email` — informational; the issue assignee on the CLI is always `@me`
  (the authenticated `gh` login), not the email.

Resolve a logical repo name (e.g. `dashboard`) to its `owner/repo` via
`github.repos.<name>`. **Always** target one explicitly with `-R owner/repo`.
If the user names a repo that isn't in `repos`, list the available ones and ask.

## Creating Issues

### Bug Report

**Title format:** `Bug: [component] - [brief description]`

```bash
gh issue create -R <owner/repo> \
  --title "Bug: [component] - [brief description]" \
  --assignee @me \
  --label "bug" \
  --body "$(cat <<'EOF'
## Summary

Brief description of the bug and its impact.

## Steps to Reproduce

1. Step one
2. Step two

## Expected Behaviour

What should happen.

## Actual Behaviour

What actually happens. Include error messages if applicable.

## Acceptance Criteria

- [ ] Bug no longer reproducible following steps above
- [ ] No related functionality broken
EOF
)"
```

### Feature Request / Task

**Title format:** `Feature: [brief description]` or `Task: [brief description]`

```bash
gh issue create -R <owner/repo> \
  --title "Feature: [brief description]" \
  --assignee @me \
  --label "enhancement" \
  --body "$(cat <<'EOF'
## Summary

Brief description of what needs to be built and why.

## Acceptance Criteria

- [ ] Criterion one
- [ ] Criterion two

## Out of Scope

- Things explicitly not in this issue

## Technical Notes

Optional implementation hints or constraints.
EOF
)"
```

### Quick Reference

```bash
# Minimal issue (resolve <owner/repo> from project.yml first)
gh issue create -R <owner/repo> -t "Task: Update Go deps" -b "Bump modules in go.mod" -a @me

# Multiple labels (comma-separated)
gh issue create -R <owner/repo> -t "Feature: Dark mode" -b "Add dark theme" -l "enhancement"

# Open the new issue in the browser after creating
gh issue create -R <owner/repo> -t "..." -b "..." --web
```

**Labels:** check what exists first — `gh label list -R <owner/repo>`. Repos use
GitHub defaults (`bug`, `enhancement`, `documentation`, `question`, etc.). Don't
invent labels on the fly; create one deliberately with `gh label create` if
genuinely needed.

## Comments

```bash
gh issue comment <num> -R <owner/repo> -b "Looking into this now"

# Multi-line
gh issue comment <num> -R <owner/repo> -b "$(cat <<'EOF'
## Progress Update

Found the root cause.

**Next steps:**
- [ ] Write fix
- [ ] Verify
EOF
)"
```

## Managing Issues

```bash
gh issue list  -R <owner/repo> [--assignee @me] [--label bug --state open]
gh issue view  <num> -R <owner/repo> [--web]
gh issue edit  <num> -R <owner/repo> [--add-label / --remove-label / --add-assignee @me]
gh issue close <num> -R <owner/repo> [-c "Resolved in #34"]
gh issue reopen <num> -R <owner/repo>
```

## Closing via commits / PRs

Include a closing keyword in the PR body or a commit message to auto-close on
merge:

```
Closes #12
Fixes #12
```

This matches the project git workflow (branch from main, PR with `gh pr create`,
never commit to main).
