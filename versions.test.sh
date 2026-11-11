#!/usr/bin/env bash
# Tests for versions.sh. Each case writes a Dockerfile fixture, runs
# versions.sh on it and checks the exit code and the output.
#
#   $ bash versions.test.sh
#
# No -e on purpose. A failed case must not stop the remaining cases.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail=0

node_line='FROM node:26.13.0-bookworm-slim AS node'
sdk10_line='FROM mcr.microsoft.com/dotnet/sdk:10.0.404-noble-aot AS sdk10'
sdk11_line='FROM mcr.microsoft.com/dotnet/sdk:11.0.100-resolute-aot AS sdk11'

fixture() {
  local file="$tmp/$1"
  shift
  {
    echo 'ARG SDK'
    printf '%s\n' "$@"
    echo 'FROM ${SDK}'
  } > "$file"
  echo "$file"
}

report() {
  if [ "$2" = ok ]; then
    printf 'ok    %s\n' "$1"
  else
    printf 'FAIL  %s: %s\n' "$1" "$3"
    fail=1
  fi
}

expect_output() {
  local name="$1" file="$2" expected="$3" actual
  if actual="$(bash "$here/versions.sh" "$file" 2>/dev/null)" && [ "$actual" = "$expected" ]; then
    report "$name" ok
  else
    report "$name" fail "got \"$actual\", expected \"$expected\""
  fi
}

expect_failure() {
  local name="$1" file="$2"
  if bash "$here/versions.sh" "$file" >/dev/null 2>&1; then
    report "$name" fail "exited 0, expected non-zero"
  else
    report "$name" ok
  fi
}

expect_output two_stages "$(fixture two "$node_line" "$sdk10_line" "$sdk11_line")" \
'SDK_MATRIX=[{"stage":"sdk10","sdk":"10.0.404"},{"stage":"sdk11","sdk":"11.0.100"}]
NODE_MAJOR=26'

expect_output one_stage "$(fixture one "$node_line" "$sdk10_line")" \
'SDK_MATRIX=[{"stage":"sdk10","sdk":"10.0.404"}]
NODE_MAJOR=26'

expect_failure no_stage "$(fixture none "$node_line")"

expect_failure missed_stage_line_fails "$(fixture missed "$node_line" "$sdk10_line" \
  'FROM mcr.microsoft.com/dotnet/sdk:11.0.100-resolute-aot as sdk11')"

expect_failure stage_major_mismatch_fails "$(fixture mismatch "$node_line" \
  'FROM mcr.microsoft.com/dotnet/sdk:11.0.100-noble-aot AS sdk10')"

expect_failure no_node_fails "$(fixture nonode "$sdk10_line")"

repo_dockerfile="$here/Dockerfile"
if out="$(bash "$here/versions.sh" "$repo_dockerfile" 2>&1)"; then
  from_lines="$(grep -c '^FROM mcr\.microsoft\.com/dotnet/sdk:' "$repo_dockerfile")"
  entries="$(printf '%s\n' "$out" | sed -n 's/^SDK_MATRIX=//p' | grep -o '"stage"' | wc -l | tr -d ' ')"
  node_major="$(printf '%s\n' "$out" | sed -n 's/^NODE_MAJOR=//p')"
  if [ "$entries" = "$from_lines" ] && [ -n "$node_major" ]; then
    report repo_dockerfile ok
  else
    report repo_dockerfile fail "${entries} entries for ${from_lines} sdk FROM lines, NODE_MAJOR=\"${node_major}\""
  fi
else
  report repo_dockerfile fail "$out"
fi

exit "$fail"
