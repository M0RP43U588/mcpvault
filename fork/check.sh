#!/usr/bin/env bash
# Checks every change must pass (cloud and Mac): frozen install, audit, build, tests, clean dist, no scripts, no network imports.
set -euo pipefail
cd "$(dirname "$0")/.."
export BUN_INSTALL_CACHE_DIR="${BUN_INSTALL_CACHE_DIR:-${TMPDIR:-/tmp}/bun-cache}"
fail() { echo "check: FAIL: $*" >&2; exit 1; }

bun install --frozen-lockfile --ignore-scripts
audit=$(bun audit 2>&1 || true)
unknown=$(grep -o 'GHSA-[0-9a-z-]*' <<<"$audit" | sort -u | grep -vxFf <(grep -v '^#' fork/accepted-advisories.txt) || true)
[ -z "$unknown" ] || { echo "$audit"; fail "unaccepted advisories: $unknown"; }
grep -q '"trustedDependencies": \[\]' package.json || fail "trustedDependencies must stay []"
[ "$(ls node_modules/.bin | sort | tr '\n' ' ')" = "esparse esvalidate js-yaml node-which tsc yaml " ] || fail "unexpected node_modules/.bin: $(ls node_modules/.bin | tr '\n' ' ')"
if grep -rEn "from ['\"](node:)?(http|https|net|tls|dns|child_process|dgram|http2|worker_threads)['\"]|\bfetch\(|Bun\.(connect|serve|spawn)|WebSocket" src --include='*.ts' --exclude='*.test.ts' | grep -v '^src/.*://'; then fail "network/process API in src"; fi
bun run build
git diff --quiet -- dist || fail "dist differs from source build; commit the rebuilt dist"
[ -z "$(git ls-files --others --exclude-standard dist)" ] || fail "untracked files in dist"
bun run test
echo "check: OK"
