#!/usr/bin/env bash
# Reads both bundled versions from the Dockerfile FROM lines and prints them as
# shell assignments. The Dockerfile is the single source of truth: when Renovate
# bumps a FROM line, the image tag and the smoke test follow without a second
# edit.
#
#   $ bash versions.sh
#   SDK_VERSION=10.0.400
#   NODE_MAJOR=24
#
# In a workflow: bash versions.sh >> "$GITHUB_ENV"
set -euo pipefail

dockerfile="${1:-Dockerfile}"

sdk="$(sed -n 's|^FROM mcr\.microsoft\.com/dotnet/sdk:\([^@]*\)-noble-aot.*|\1|p' "$dockerfile")"
node_major="$(sed -n 's|^FROM node:\([0-9][0-9]*\)\..*AS node.*|\1|p' "$dockerfile")"

if [ -z "$sdk" ]; then
  echo "cannot read the .NET SDK version from ${dockerfile}" >&2
  exit 1
fi

if [ -z "$node_major" ]; then
  echo "cannot read the node major version from ${dockerfile}" >&2
  exit 1
fi

echo "SDK_VERSION=${sdk}"
echo "NODE_MAJOR=${node_major}"
