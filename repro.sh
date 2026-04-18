#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

pattern='*darwin-rebuild-stale-tmp*.tmp'

existing_tmp="$(find /nix/store -maxdepth 1 -name "$pattern" -print -quit 2>/dev/null || true)"
if [[ -n "${existing_tmp}" ]]; then
  printf 'Existing stale temp path found: %s\n' "$existing_tmp" >&2
  printf 'Clean it up first, e.g. with sudo rm -rf %q\n' "$existing_tmp" >&2
  exit 1
fi

rm -f first-rebuild.log second-rebuild.log

echo '1. Realize the derivation once.'
nix build .#multi --no-link

echo '2. Start a rebuild-check and interrupt it after hash rewriting begins.'
NIX_DEBUG=6 nix build .#multi --no-link --rebuild -L -vvvv > first-rebuild.log 2>&1 &
client_pid=$!

for _ in $(seq 1 1200); do
  if rg -q 'rewriting hashes in ' first-rebuild.log; then
    break
  fi
  sleep 0.05
done

if ! rg -q 'rewriting hashes in ' first-rebuild.log; then
  printf 'Did not observe the rewrite phase.\n' >&2
  wait "$client_pid" || true
  exit 1
fi

kill -9 "$client_pid" 2>/dev/null || true
sleep 1

stale_tmp="$(find /nix/store -maxdepth 1 -name "$pattern" -print -quit 2>/dev/null || true)"
if [[ -z "${stale_tmp}" ]]; then
  printf 'Expected a stale temp path after interruption, but none was found.\n' >&2
  exit 1
fi

printf 'Stranded temp path: %s\n' "$stale_tmp"
ls -ld "$stale_tmp"

echo '3. Run rebuild-check again. It should now fail because the temp path already exists.'
status=0
nix build .#multi --no-link --rebuild -L > second-rebuild.log 2>&1 || status=$?

cat second-rebuild.log

if [[ "$status" -eq 0 ]]; then
  printf 'Expected the second rebuild to fail, but it succeeded.\n' >&2
  exit 1
fi

if ! rg -q 'already exists|File exists' second-rebuild.log; then
  printf 'Expected an existing-temp-path failure, but saw a different error.\n' >&2
  exit 1
fi

echo
echo 'Reproduction succeeded.'
