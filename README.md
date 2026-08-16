# dotnet-sdk-runner

Forgejo CI pipelines build .NET applications in this container image. It holds
the .NET SDK, the NativeAOT toolchain and a `node` binary, so a workflow needs
one image and no install step.

GitHub Actions builds the image and pushes it to
`ghcr.io/raeffs/dotnet-sdk-runner`. The Forgejo runner pulls it from there. The
build never contacts Forgejo, because GitHub cannot reach that host.

## What is in it

| Tool | Source |
| --- | --- |
| .NET SDK 10.0.400 | base image `mcr.microsoft.com/dotnet/sdk:10.0.400-noble-aot` |
| NativeAOT toolchain: `clang`, `cc`, `ld.bfd`, `objcopy`, `libz.a` | the `-aot` suffix on the base image |
| `git`, `curl`, `wget`, `tar`, `sed`, `grep` | base image |
| `node` 24 | one binary copied from `node:24.19.0-bookworm-slim` |
| `unzip`, `jq` | Ubuntu Noble packages |

The image is 2.07 GB. It builds for `linux/amd64` only.

There is no `npm` and no `node_modules`. JavaScript actions ship bundled code,
so `actions/checkout` and the other JavaScript actions run on the bare `node`
binary.

## Use it

Replace the image in a Forgejo workflow:

```yaml
jobs:
  build:
    runs-on: docker
    container:
      image: ghcr.io/raeffs/dotnet-sdk-runner:10.0.400-node24-1
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
      - run: dotnet build --configuration Release
```

Read the current tag from the [package
page](https://github.com/raeffs/dotnet-sdk-runner/pkgs/container/dotnet-sdk-runner).

GHCR keeps a package private until you publish it. After the first build, set
the package to public in the GitHub package settings. Until then the Forgejo
runner cannot pull the image.

## Tags

A tag looks like `10.0.400-node24-1`:

| Part | Meaning |
| --- | --- |
| `10.0.400` | the .NET SDK version |
| `node24` | the node major version |
| `1` | `github.run_number` |

Nothing overwrites a published tag, and there is no `latest` tag. The Forgejo
runner defaults to `container.force_pull: false`: it pulls a tag once and then
reuses the local copy. A consumer that points at a moving tag keeps the first
digest it pulled and never sees a later build.

The run number keeps each tag unique. A weekly rebuild that changes neither
version still publishes a new tag, and `github.run_number` only rises, so a
later build always sorts after an earlier one.

The tag carries the node major version only. The Dockerfile pins node to an
exact patch version, so a node patch shows up as a new run number rather than a
new name.

## Change it

Add new tools to the last `RUN` layer, below the `COPY`. A change there leaves
the 1.9 GB base layer intact, so a consumer pulls a small layer instead of the
whole image.

Both `FROM` lines are pinned to an exact version. Renovate raises a pull request
to move them. Do not switch either line to a moving tag. The pin records which
version CI used when a build breaks.

The two `apt-get` packages stay unpinned on purpose. They are small, and the
weekly rebuild picks up Ubuntu security updates for them. Keep
`--no-install-recommends` and the `rm -rf /var/lib/apt/lists/*`.

`versions.sh` reads both versions from the `FROM` lines. The build workflow and
the smoke test both call it, so a Renovate bump moves the image tag and the test
expectations with it. There is no second place to edit.

## Build and test it locally

```bash
docker build -t dotnet-sdk-runner:local .
eval "$(bash versions.sh)"
docker run --rm -v "${PWD}/smoke.sh:/smoke.sh:ro" dotnet-sdk-runner:local \
  bash /smoke.sh "$SDK_VERSION" "$NODE_MAJOR"
```

`smoke.sh` prints one line per check. It reports every failure before it exits,
so one run shows the full list. It exits 1 if any check failed.

On Windows, run this in Git Bash and set `MSYS_NO_PATHCONV=1`. Without it, Git
Bash rewrites the container path `/smoke.sh` into a Windows path and the mount
fails.

## The build workflow

`.github/workflows/build.yml` runs on a push to `main`, on `workflow_dispatch`,
and weekly on a schedule.

It builds, then smoke-tests, then pushes, in that order. A failed smoke test
stops the push, so a broken image never reaches the registry. It logs in with
`github.token`. GHCR needs no personal access token for a push from the same
account.

`.forgejo/workflows/validate.yml` runs on Forgejo. It validates `renovate.json`
and checks that `versions.sh` still parses both `FROM` lines. It also keeps
Forgejo away from the GitHub workflow: Forgejo scans `.forgejo/workflows`,
`.gitea/workflows` and `.github/workflows`, and runs the first directory it
finds. Delete that file and the Forgejo runner starts running the GitHub build
workflow.

## Renovate in consumers

Renovate finds both `FROM` lines in this repository through the default
`dockerfile` manager. This repository needs no extra configuration.

A consumer needs a custom manager. Its workflows live in `.forgejo/workflows/`,
which the `github-actions` manager does not read:

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "description": "Forgejo workflows sit outside the github-actions manager; track the CI image tag here",
      "managerFilePatterns": ["/^\\.forgejo/workflows/.+\\.ya?ml$/"],
      "matchStrings": [
        "image:\\s*(?<depName>ghcr\\.io/raeffs/dotnet-sdk-runner):(?<currentValue>\\S+)"
      ],
      "datasourceTemplate": "docker",
      "versioningTemplate": "regex:^(?<major>\\d+)\\.(?<minor>\\d+)\\.(?<patch>\\d+)-node(?<build>\\d+)-(?<revision>\\d+)$"
    }
  ]
}
```

The versioning maps the SDK version to `major.minor.patch`, the node major
version to `build`, and the run number to `revision`. All five groups are
numeric, so Renovate orders the tags correctly and offers an upgrade whichever
part moved.

Put this in the shared `renovate-config` repository rather than in each
consumer. Every repository extends `local>renovate-bot/renovate-config`, so one
edit covers all of them.
