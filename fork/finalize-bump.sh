#!/usr/bin/env bash
# Mac: bash fork/finalize-bump.sh <tag> [<branch>]  (default branch claude/bump-mcpvault-<tag>)
# Verifies a prepared bump branch (rebased onto the tag, so main is replaced, not fast-forwarded), moves main and
# upstream-release onto it, deletes the branch.
set -euo pipefail
cd "$(dirname "$0")/.."
tag=${1:?usage: finalize-bump.sh <tag> [<branch>]}; branch=${2:-claude/bump-mcpvault-$tag}
[ -z "$(git status --porcelain)" ] || { echo "finalize: working tree not clean" >&2; exit 1; }
git switch main
git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/bitbonsai/mcpvault
git remote set-url --push upstream DISABLED
git fetch origin main "$branch"
git fetch upstream tag "$tag" --no-tags
git merge-base --is-ancestor "refs/tags/$tag" "origin/$branch" || { echo "finalize: $branch does not contain $tag" >&2; exit 1; }
git merge --ff-only origin/main
[ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ] || { echo "finalize: local main has unpushed commits; push or drop them first" >&2; exit 1; }
git merge-base --is-ancestor "origin/$branch" main && { echo "finalize: $branch is not ahead of main" >&2; exit 1; }
oldmain=$(git rev-parse main)
git switch -q --detach "origin/$branch"
bash fork/check.sh
git switch -q main
git reset -q --hard "origin/$branch"
git push --force-with-lease="main:$oldmain" origin main
git branch -f upstream-release "refs/tags/$tag"
git push -f origin upstream-release
git push origin --delete "$branch"
git branch -D "$branch" 2>/dev/null || true
git fetch --prune origin
git tag -d "$tag" 2>/dev/null || true
echo "finalize: old main was $oldmain; main now at $(git rev-parse --short HEAD). Restart Claude Desktop to load the new dist."
