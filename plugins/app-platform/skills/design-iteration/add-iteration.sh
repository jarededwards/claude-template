#!/usr/bin/env bash
# Add a new design handoff zip to a project's design-archive repo as a diffable
# iteration on a branch, push it, and open a PR. The PR diff is the build spec.
#
# Generic: the archive repo location is passed in (resolved from
# .claude/project.yml -> design.archive_dir), not hardcoded.
#
# Usage: add-iteration.sh <archive-dir> <path-to-zip> ["optional summary"]
set -euo pipefail

ARCHIVE="${1:-}"
ZIP="${2:-}"
SUMMARY="${3:-}"

# Expand a leading ~ in the archive path.
ARCHIVE="${ARCHIVE/#\~/$HOME}"

if [ -z "$ARCHIVE" ] || [ ! -d "$ARCHIVE/.git" ]; then
  echo "ERROR: design-archive git repo not found at: '$ARCHIVE'" >&2
  echo "       Pass design.archive_dir from .claude/project.yml as the first arg." >&2
  exit 1
fi
if [ -z "$ZIP" ] || [ ! -f "$ZIP" ]; then
  echo "ERROR: pass a path to an existing .zip — got: '$ZIP'" >&2
  exit 1
fi
ZIP="$(cd "$(dirname "$ZIP")" && pwd)/$(basename "$ZIP")"   # absolutize

cd "$ARCHIVE"

# Sync main
git checkout -q main
git pull -q --ff-only origin main 2>/dev/null || true

# Next iteration number = (existing "iteration N" commits) + 1
N=$(( $(git log --oneline --format='%s' | grep -c '^iteration ') + 1 ))
BRANCH="design/iteration-$N"

git switch -c "$BRANCH" 2>/dev/null || git switch "$BRANCH"

# Extract + locate the dir that actually holds the code (handles both nested
# project/*.jsx layouts and flat zips).
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q -o "$ZIP" -d "$TMP"

# Prefer a dir containing app.jsx or admin.jsx; otherwise fall back to the dir
# with the most design files (jsx/js/css/html).
CODEDIR="$(dirname "$(find "$TMP" -name app.jsx 2>/dev/null | head -1)")"
if [ -z "$CODEDIR" ] || [ "$CODEDIR" = "." ]; then
  CODEDIR="$(dirname "$(find "$TMP" -name admin.jsx 2>/dev/null | head -1)")"
fi
if [ -z "$CODEDIR" ] || [ ! -d "$CODEDIR" ] || [ "$CODEDIR" = "." ]; then
  CODEDIR="$(
    find "$TMP" -type f \( -name '*.jsx' -o -name '*.js' -o -name '*.css' -o -name '*.html' \) \
      -exec dirname {} \; 2>/dev/null | sort | uniq -c | sort -rn | head -1 | awk '{print $2}'
  )"
fi
if [ -z "$CODEDIR" ] || [ ! -d "$CODEDIR" ]; then
  echo "ERROR: could not find any design code files (jsx/js/css/html) inside the zip" >&2
  exit 1
fi

# Replace tracked code files (uploads/screenshots stay gitignored)
mkdir -p project
find project -maxdepth 1 -type f \( -name '*.jsx' -o -name '*.js' -o -name '*.css' -o -name '*.html' \) -delete
cp "$CODEDIR"/*.jsx "$CODEDIR"/*.js "$CODEDIR"/*.css "$CODEDIR"/*.html project/ 2>/dev/null || true

# Stage code changes first to detect a no-op iteration (identical design).
git add project/
if git diff --cached --quiet; then
  echo "No code changes vs main — this zip is identical to the current iteration. Nothing to do." >&2
  git switch -q main
  git branch -q -D "$BRANCH"
  exit 0
fi

# Archive the source zip itself into the heavy-artifact store (zips/).
mkdir -p zips
cp "$ZIP" zips/ 2>/dev/null || true
git add -A

ZNAME="$(basename "$ZIP")"
MSG="iteration $N — $ZNAME"
[ -n "$SUMMARY" ] && MSG="$MSG ($SUMMARY)"
ZDATE="$(stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' "$ZIP" 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S')"

GIT_AUTHOR_DATE="$ZDATE" GIT_COMMITTER_DATE="$ZDATE" git commit -q -m "$MSG"
git push -q -u origin "$BRANCH"

# Open a PR; its diff vs main is the build spec.
PR_BODY="Design **iteration $N** from \`$ZNAME\` (zip dated $ZDATE).

Review the **Files changed** diff — that delta is exactly what to build/adjust in the app to match the new design.

${SUMMARY:+> $SUMMARY}"
gh pr create --base main --head "$BRANCH" \
  --title "Design iteration $N — $ZNAME" \
  --body "$PR_BODY" 2>/dev/null \
  && gh pr view "$BRANCH" --json url -q '.url' \
  || echo "Branch pushed ($BRANCH). Open the PR manually if 'gh pr create' was skipped."

echo ""
echo "Iteration $N added on branch $BRANCH. Diff vs previous iteration:"
echo "  git -C $ARCHIVE diff main..$BRANCH -- project/"
