# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom

ARG SDK

FROM node:26.13.1-bookworm-slim AS node
FROM mcr.microsoft.com/dotnet/sdk:10.0.404-noble-aot AS sdk10
FROM mcr.microsoft.com/dotnet/sdk:11.0.100-resolute-aot AS sdk11

FROM ${SDK}

COPY --from=node /usr/local/bin/node /usr/local/bin/node

RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip jq \
 && rm -rf /var/lib/apt/lists/*

ENV DOTNET_NOLOGO=1 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1
