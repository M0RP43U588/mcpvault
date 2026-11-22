---
name: bump
description: Bump the mcpvault fork to a new bitbonsai/mcpvault release. Cloud half prepares and pushes a branch; fork/finalize-bump.sh on the Mac verifies and moves main. Use when asked to bump, update or sync the fork.
---

# mcpvault bump (upstream: bitbonsai/mcpvault)

Branch `claude/bump-mcpvault-<tag>`. Commits: `bump(mcpvault): <tag>`, `fork(mcpvault): <summary>`. No attribution lines. The cloud never pushes `main`, `upstream-release` or tags for a bump.

1. Setup: `git fetch --unshallow origin` if shallow; add remote `upstream` (https://github.com/bitbonsai/mcpvault, push URL `DISABLED`); `git fetch upstream --tags`. The GitHub API is not reachable; use git only. Tag = newest `vX.Y.Z` in `git ls-remote --tags upstream`. Base = `origin/upstream-release` if it exists, else `git merge-base main upstream/main`. Stop if the base already is the tag.
2. Review `git diff <base>..<tag>` for the focus list in CLAUDE.md "Upstream sync" (deps and install scripts, path handling, write/move ops, delete/trash, network or transports, `.claude/`, `.github/`, `scripts/`). `website-shibumi/`, `skills/`, `benchmarks/` need no review. Ask Delta (request_decision) only for risky findings or new tools or deps; keep the rest silent.
3. `git switch -c claude/bump-mcpvault-<tag> main`, then `git rebase --onto <tag> <base>`. Resolve conflicts keeping the fork rules: no delete tool or `trash`, `refuseEngine` in `src/frontmatter.ts`, `.obsidian` excluded. Never take upstream's lockfiles or `dist/`; mirror upstream dependency bumps by hand as exact pins, then `bun install --no-frozen-lockfile --ignore-scripts`. A new dependency needs Delta's approval.
4. Rebuild `dist/` (`bun run build`) and commit it with `bump(mcpvault): <tag>`.
5. `bash fork/check.sh` (frozen install, audit against `fork/accepted-advisories.txt`, build, clean dist, tests, no network imports). Fix or ask; never loosen the checks.
6. Push the branch. Report only the outcome, decisions needed, and: "On the Mac, Claude Desktop closed: `git switch main && bash fork/finalize-bump.sh <tag>`" (verifies, moves `main` and `upstream-release`, deletes the branch).

Workflow or tooling changes (not bumps) go on a `claude/` branch, pass `fork/check.sh`, then fast-forward `main`.
