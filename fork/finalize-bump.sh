#!/usr/bin/env bash
# Mac: bash fork/finalize-bump.sh <tag> [<branch>]  (default branch claude/bump-mcpvault-<tag>)
# Verifies a prepared bump branch, moves main and upstream-release onto it, deletes the branch.
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
git merge-base --is-ancestor main "origin/$branch" || { echo "finalize: $branch is not ahead of main" >&2; exit 1; }
git switch -q --detach "origin/$branch"
bash fork/check.sh
git switch -q main
git merge --ff-only "origin/$branch"
git push origin main
git branch -f upstream-release "refs/tags/$tag"
git push -f origin upstream-release
git push origin --delete "$branch"
git branch -D "$branch" 2>/dev/null || true
git fetch --prune origin
git tag -d "$tag" 2>/dev/null || true
echo "finalize: main at $(git rev-parse --short HEAD). Restart Claude Desktop to load the new dist."
