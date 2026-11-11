#!/usr/bin/env bash
# Reads the image variants and the bundled node major from the Dockerfile FROM
# lines and prints them as shell assignments. Each variant is one stage
# "FROM mcr.microsoft.com/dotnet/sdk:<x.y.z>-<distro>-aot AS sdk<major>". The
# Dockerfile is the single source of truth: when Renovate bumps a FROM line or
# someone adds a stage, the build matrix, the image tags and the smoke test
# follow without a second edit.
#
#   $ bash versions.sh
#   SDK_MATRIX=[{"stage":"sdk10","sdk":"10.0.404"},{"stage":"sdk11","sdk":"11.0.100"}]
#   NODE_MAJOR=26
#
# In a workflow: bash versions.sh >> "$GITHUB_OUTPUT"
set -euo pipefail

dockerfile="${1:-Dockerfile}"

from_lines="$(grep -ciE '^[[:space:]]*FROM[[:space:]].*mcr\.microsoft\.com/dotnet/sdk:' "$dockerfile" || true)"
stages="$(sed -n 's|^FROM mcr\.microsoft\.com/dotnet/sdk:\([0-9][0-9]*\)\(\.[0-9][0-9]*\.[0-9][0-9]*\)-[^ ]* AS sdk\([0-9][0-9]*\)$|\3 \1 \1\2|p' "$dockerfile")"
node_major="$(sed -n 's|^FROM node:\([0-9][0-9]*\)\..*AS node.*|\1|p' "$dockerfile")"

if [ "$from_lines" -eq 0 ]; then
  echo "cannot find a .NET SDK stage in ${dockerfile}" >&2
  exit 1
fi

entries=()
while read -r stage_major sdk_major sdk; do
  if [ "$stage_major" != "$sdk_major" ]; then
    echo "stage sdk${stage_major} holds .NET SDK ${sdk} in ${dockerfile}" >&2
    exit 1
  fi
  entries+=("{\"stage\":\"sdk${stage_major}\",\"sdk\":\"${sdk}\"}")
done <<< "$stages"

if [ -z "$stages" ] || [ "${#entries[@]}" -ne "$from_lines" ]; then
  echo "cannot read every .NET SDK stage in ${dockerfile}: expected one 'FROM mcr.microsoft.com/dotnet/sdk:<x.y.z>-<distro>-aot AS sdk<major>' line per stage" >&2
  exit 1
fi

if [ -z "$node_major" ]; then
  echo "cannot read the node major version from ${dockerfile}" >&2
  exit 1
fi

matrix="$(IFS=,; echo "${entries[*]}")"
echo "SDK_MATRIX=[${matrix}]"
echo "NODE_MAJOR=${node_major}"
