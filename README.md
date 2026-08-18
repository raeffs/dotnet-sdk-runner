# dotnet-sdk-runner

Forgejo CI pipelines build .NET applications in this container image. It holds
the .NET SDK, the NativeAOT toolchain and a `node` binary, so a workflow needs
one image and no install step.

## What is in it

| Tool | Source |
| --- | --- |
| .NET SDK 10.0.400 | base image `mcr.microsoft.com/dotnet/sdk:10.0.400-noble-aot` |
| NativeAOT toolchain: `clang`, `cc`, `ld.bfd`, `objcopy`, `libz.a` | the `-aot` suffix on the base image |
| `git`, `curl`, `wget`, `tar`, `sed`, `grep` | base image |
| `node` 24 | one binary copied from `node:24.19.0-bookworm-slim` |
| `unzip`, `jq` | Ubuntu Noble packages |
