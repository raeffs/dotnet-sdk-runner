#!/usr/bin/env bash
# Checks that the built image holds every tool the pipelines call, and that the
# two bundled versions are the ones the Dockerfile asked for.
#
#   $ bash smoke.sh 10.0.400 24
#
# No -e on purpose. A failed check must not stop the remaining checks, so one
# run reports the full list of problems.
set -uo pipefail

expected_sdk="${1:?expected .NET SDK version required}"
expected_node_major="${2:?expected node major version required}"
fail=0

for t in dotnet node git unzip jq curl wget tar clang cc ld.bfd objcopy; do
  if command -v "$t" >/dev/null 2>&1; then
    printf 'ok    %-12s %s\n' "$t" "$(command -v "$t")"
  else
    printf 'FAIL  %-12s not found\n' "$t"
    fail=1
  fi
done

if [ -f /usr/lib/x86_64-linux-gnu/libz.a ]; then
  printf 'ok    %-12s %s\n' libz.a /usr/lib/x86_64-linux-gnu/libz.a
else
  printf 'FAIL  %-12s not found (NativeAOT linking needs it)\n' libz.a
  fail=1
fi

actual_sdk="$(dotnet --version 2>/dev/null)"
if [ "$actual_sdk" = "$expected_sdk" ]; then
  printf 'ok    %-12s %s\n' dotnet-ver "$actual_sdk"
else
  printf 'FAIL  %-12s got "%s", expected "%s"\n' dotnet-ver "$actual_sdk" "$expected_sdk"
  fail=1
fi

actual_node="$(node --version 2>/dev/null)"
case "$actual_node" in
  "v${expected_node_major}."*)
    printf 'ok    %-12s %s\n' node-ver "$actual_node"
    ;;
  *)
    printf 'FAIL  %-12s got "%s", expected "v%s.x"\n' node-ver "$actual_node" "$expected_node_major"
    fail=1
    ;;
esac

exit "$fail"
