# dotnet-sdk-runner

Forgejo CI pipelines build .NET applications in this container image. It holds
the .NET SDK, the NativeAOT toolchain and a `node` binary, so a workflow needs
one image and no install step.

## Variants

The repo builds one image for each .NET SDK major. Each variant is one stage in
the `Dockerfile`:

| Stage | Base image | Ubuntu release |
| --- | --- | --- |
| `sdk10` | `mcr.microsoft.com/dotnet/sdk:<x.y.z>-noble-aot` | Noble (24.04) |
| `sdk11` | `mcr.microsoft.com/dotnet/sdk:<x.y.z>-resolute-aot` | Resolute (26.04) |

All variants publish to `ghcr.io/raeffs/dotnet-sdk-runner`. The tag is
`<sdk>-node<major>-<run>`, for example `11.0.100-node26-57`. The `Dockerfile`
holds the exact SDK and Node versions.

## What is in it

Every variant has the same tools:

| Tool | Source |
| --- | --- |
| .NET SDK | base image |
| NativeAOT toolchain: `cc`, `ld.bfd`, `objcopy`, `libz.a` | the `-aot` suffix on the base image |
| `git`, `curl`, `wget`, `tar`, `sed`, `grep` | base image |
| `node` | one binary copied from the `node` image |
| `unzip`, `jq` | Ubuntu packages |

The `sdk10` base image links NativeAOT with clang. The `sdk11` base image links
with GCC and has no `clang`.

## Add or remove a .NET major

To add a major, put a new stage line below the other SDK stages in the
`Dockerfile`:

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:<x.y.z>-<distro>-aot AS sdk<major>
```

The build picks up the new stage without other edits. Renovate does not offer
major updates of the SDK image, so you must add each new major yourself.

To remove a major, delete its stage line.
