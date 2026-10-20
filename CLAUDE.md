# CLAUDE.md — mcpvault (personal hardened fork)

## Purpose
Personal hardened fork of [bitbonsai/mcpvault](https://github.com/bitbonsai/mcpvault).
It is a local filesystem MCP server (stdio) for my iCloud Obsidian vault, used from Claude Desktop.
Goals: reduce supply-chain risk, keep the surface small, optimize.

- Vault: `/Users/anon/Library/Mobile Documents/iCloud~md~obsidian/Documents/omnia`
- Toolchain: **Bun only** (no Node/npm installed). `AGENTS.md` is upstream's architecture doc; where it conflicts with this file (npm, vitest, website, publishing), this file wins.

## Hard rules
1. **The vault path is the only allowed root.** Every path input goes through `normalizePath` + `resolvePath` + `pathFilter.isAllowed` (mirror `readNote`'s guard). No `..` traversal, and no symlinks that resolve outside the vault.
2. **No network access.** Runtime code may import only node builtins `fs`, `fs/promises`, `path`, `os`, `url`, `buffer` and `process`, plus the pinned deps. Never add `fetch`, `http(s)`, `net`, `tls`, `dns`, `child_process`, `WebSocket`, `Bun.connect/serve/spawn` or any HTTP/SSE MCP transport.
3. **`.obsidian` stays excluded** (`PathFilter`, together with `.git`, `.trash` and dotfiles). Never loosen `PathFilter` defaults.
4. **No delete.** `delete_note` and the `trash` dependency are removed. Don't reintroduce them.
5. **gray-matter non-YAML engines stay disabled** (`refuseEngine` in `src/frontmatter.ts`). Upstream's default lets a `---js` note `eval()` code on read. The tests in `src/frontmatter.test.ts` must keep passing.

## Running (Claude Desktop)
Only the local build runs, never `npx`, `bunx`, `@latest` or a registry package:
```json
"mcpvault": {
  "command": "/opt/homebrew/bin/bun",
  "args": ["--no-install", "/Users/anon/projects/mcpvault/dist/server.js",
           "/Users/anon/Library/Mobile Documents/iCloud~md~obsidian/Documents/omnia"],
  "env": { "DO_NOT_TRACK": "1" }
}
```
`--no-install` (plus `install.auto = "disable"` in `bunfig.toml`) stops Bun from auto-installing missing imports from npm at runtime.

## Dependencies & install scripts
- **Exact versions only** in `package.json` (no `^`/`~`). `bunfig.toml` sets `install.exact = true`.
- **Commit `bun.lock`.** It is the only lockfile; upstream's `package-lock.json` and stale `bun.lock` were removed.
- **Install only with** `bun install --frozen-lockfile --ignore-scripts`. Never run a bare `bun install`/`bun add`.
- **`trustedDependencies` stays `[]`.** The empty list also disables Bun's built-in allowlist, so no dependency lifecycle script (postinstall etc.) ever runs. Never add entries.
- After any install, `bun pm untrusted` must show no scripts executed. Check that `node_modules/.bin` only contains `tsc`, `yaml`, `js-yaml`, `esparse`, `esvalidate`, `node-which`.
- Run installs, builds and tests inside the Claude Code Bash sandbox, with `BUN_INSTALL_CACHE_DIR=$TMPDIR/bun-cache` and network limited to `registry.npmjs.org`.
- `minimumReleaseAge = 7 days` in `bunfig.toml`: freshly published (possibly hijacked) versions are refused.
- **No new dependencies (runtime or dev) without asking me first.** Prefer removing deps.
- Root `package.json` has no lifecycle hooks (`prepare`, `prepack`, `postinstall`…) and is `private: true`. Keep it that way.

## Audit, build, test
Run **`bun audit` before every build or update** and report the findings.
```bash
bun install --frozen-lockfile --ignore-scripts
bun audit
bun run build      # bun node_modules/typescript/bin/tsc -p tsconfig.build.json → dist/
bun run test       # bun test (vitest imports are rewritten to bun:test; vitest is not installed)
```
`dist/` is committed (as upstream does). Rebuild and commit it in the same change as any `src/` change, and never trust a prebuilt `dist/` from upstream.

Known, accepted advisories (re-check on every update):
- `@modelcontextprotocol/client` 2.0.0, GHSA-6qxp-vccf-f47h (OAuth): dev-only (tests), and OAuth is never used.
- `sprintf-js` 1.0.3, GHSA-hp3w-g68c-fv3c (via gray-matter > js-yaml > argparse): `argparse` is only used by js-yaml's CLI and is outside the runtime import graph.

## Upstream sync
Remotes: `origin` = my fork, `upstream` = bitbonsai/mcpvault (push URL set to `DISABLED`).
1. `git fetch upstream`
2. Review `git log main..upstream/main` and `git diff main...upstream/main` with focus on:
   - dependency changes: `package.json` and upstream `package-lock.json` (which signals bumps I mirror by hand into our exact pins + `bun.lock`), new install scripts
   - path handling / traversal: `src/pathfilter.ts`, `normalizePath`, `resolvePath`, symlink checks, new tools' path guards
   - write/delete/move ops in `src/filesystem.ts`, and anything that reintroduces delete or `trash`
   - any network calls or new transports
   - `.claude/`, `.github/workflows/`, `scripts/` (code that runs on my machine or in CI)
3. Summarize the findings and **merge only after my explicit approval**. Then run audit → build → test, and recommit `dist/`.
4. `website-shibumi/`, `skills/`, `benchmarks/` and the deploy files are upstream-only and never run here. Accept their changes without review.

## Optimization
- Tool surface: 17 tools (upstream's 18 minus `delete_note`). Keep read, search, write, patch and frontmatter tools. Ask before removing more.
- 14 runtime packages are installed. 11 are reachable from `dist/server.js`: MCP server/core, zod, gray-matter (+ js-yaml, section-matter, kind-of, extend-shallow, is-extendable, strip-bom-string) and yaml; argparse, sprintf-js and esprima are installed but never loaded. Upstream had 80 runtime packages, ~60 of them from `trash`. Check the closure with `bun build dist/server.js --target=bun --metafile=…`.
- Dev deps are only `typescript`, `@types/node` and `@modelcontextprotocol/client` (tests). tsx, vitest and @clack/prompts were dropped.
