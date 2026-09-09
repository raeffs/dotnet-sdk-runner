# syntax=docker/dockerfile:1

FROM node:24.21.0-bookworm-slim AS node
FROM mcr.microsoft.com/dotnet/sdk:10.0.401-noble-aot

COPY --from=node /usr/local/bin/node /usr/local/bin/node

RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip jq \
 && rm -rf /var/lib/apt/lists/*

ENV DOTNET_NOLOGO=1 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1
