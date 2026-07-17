# workflows

iwamot's shared reusable GitHub Actions workflows.

## Workflows

| Workflow | Purpose |
|----------|---------|
| `compatibility-go.yml` | Run the caller's `compatibility.sh` across a matrix of Go versions. |
| `compatibility-node.yml` | Run the caller's `compatibility.sh` across a matrix of Node.js versions. |
| `compatibility-python.yml` | Run the caller's `compatibility.sh` across a matrix of Python versions. |
| `dco.yml` | Enforce Developer Certificate of Origin (DCO) sign-off on pull requests. |
| `dependabot-auto-merge.yml` | Enable auto-merge for non-major Dependabot PRs. |
| `dependency-review.yml` | Run `actions/dependency-review-action` on pull requests. |
| `release-ecr-public.yml` | Release a multi-arch Docker image to Amazon ECR Public (cosign-signed, SBOM-attested, build-provenance-attested). |
| `release-ghcr.yml` | Release a multi-arch Docker image to `ghcr.io/<owner>/<repo>` (cosign-signed, SBOM-attested, build-provenance-attested). |
| `release-homebrew-tap.yml` | Release a Go CLI as a Homebrew cask via `iwamot/homebrew-tap` (build-provenance-attested). |
| `release-only.yml` | Create a GitHub Release from a pushed tag with auto-generated notes. |
| `renovate.yml` | Run Renovate with GitHub App authentication. |
| `validate.yml` | Run `validate.sh` under mise. |
| `validate-with-coverage.yml` | Run `validate.sh` under mise and upload coverage to Codecov. |

## Usage

Each workflow is invoked from a caller workflow via `uses:` at the job level. The caller defines its own triggers and workflow-level `permissions`.

### `compatibility-go.yml`

Run a caller-provided `compatibility.sh` under each Go version in the matrix. The caller's `mise.toml` must declare `go` under `[tools]`; the matrix version is exported as `MISE_GO_VERSION`, overriding that entry. The script defines what "compatibility" means; `mise` is preinstalled on the runner but no tools are installed, so the script must call `mise install` itself.

A typical script exercises the `go install` path in an isolated `GOBIN`:

```bash
#!/bin/bash
set -euo pipefail

eval "$(mise activate bash)"
mise install

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

GOBIN="$TMP" go install ./...
"$TMP/<cli>" --version
```

```yaml
name: Compatibility

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  compatibility:
    uses: iwamot/workflows/.github/workflows/compatibility-go.yml@<sha> # vX.X.X
    with:
      go-versions: '["1.25","1.26"]'
```

### `compatibility-node.yml`

Run a caller-provided `compatibility.sh` under each Node.js version in the matrix. The caller's `mise.toml` must declare `node` under `[tools]`; the matrix version is exported as `MISE_NODE_VERSION`, overriding that entry. The script defines what "compatibility" means; `mise` is preinstalled on the runner but no tools are installed, so the script must call `mise install` itself.

A typical script builds the package once and exercises the packed tarball in an isolated directory:

```bash
#!/bin/bash
set -euo pipefail

eval "$(mise activate bash)"
mise install

bun install --frozen-lockfile
bun run build

TARBALL="$PWD/$(npm pack --silent)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"; rm -f "$TARBALL"' EXIT

cd "$TMP"
npm init --silent --yes > /dev/null
npm install --silent --no-audit --no-fund "$TARBALL"

./node_modules/.bin/<cli> --version
```

```yaml
name: Compatibility

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  compatibility:
    uses: iwamot/workflows/.github/workflows/compatibility-node.yml@<sha> # vX.X.X
    with:
      node-versions: '["20","22","24"]'
```

### `compatibility-python.yml`

Run a caller-provided `compatibility.sh` under each Python version in the matrix. The caller's `mise.toml` must declare `aqua:astral-sh/uv` under `[tools]`; the matrix version is exported as `UV_PYTHON` for `uv` to pick up. The script defines what "compatibility" means; `mise` is preinstalled on the runner but no tools are installed, so the script must call `mise install` itself.

Use this canonical name when invoking `mise install <tool>` explicitly — a short alias like `mise install uv` may install the binary but leave the shim inactive in a clean environment.

A typical script builds the wheel once and exercises it under the matrix Python in an isolated environment:

```bash
#!/bin/bash
set -e

eval "$(mise activate bash)"
mise install aqua:astral-sh/uv

uv build --wheel --out-dir dist
uv run --isolated --no-project --with ./dist/*.whl <cli> <fixture>
```

```yaml
name: Compatibility

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  compatibility:
    uses: iwamot/workflows/.github/workflows/compatibility-python.yml@<sha> # vX.X.X
    with:
      python-versions: '["3.11","3.12","3.13","3.14"]'
```

### `dco.yml`

Wraps `KineticCafe/actions-dco` to enforce Developer Certificate of Origin (DCO) sign-off on pull request commits. Bot-authored commits are skipped automatically by the action.

```yaml
name: DCO

on:
  pull_request:

permissions: {}

jobs:
  dco:
    uses: iwamot/workflows/.github/workflows/dco.yml@<sha> # vX.X.X
```

### `dependabot-auto-merge.yml`

Enable auto-merge on Dependabot PRs that are not major version bumps. Requires Dependabot to be enabled for the caller's repo (via `.github/dependabot.yml` or repo settings).

```yaml
name: Dependabot auto-merge

on: pull_request

permissions:
  contents: write
  pull-requests: write

jobs:
  dependabot-auto-merge:
    uses: iwamot/workflows/.github/workflows/dependabot-auto-merge.yml@<sha> # vX.X.X
```

### `dependency-review.yml`

Wraps `actions/dependency-review-action` to flag dependency changes that introduce known vulnerabilities on pull requests. The optional `allow-ghsas` input (comma-separated GitHub Advisory IDs, passed via `with:`) waives specific advisories, e.g. ones with no patched version available.

```yaml
name: 'Dependency review'

on:
  pull_request:
    branches: [ "main" ]

permissions:
  contents: read
  pull-requests: write

jobs:
  dependency-review:
    uses: iwamot/workflows/.github/workflows/dependency-review.yml@<sha> # vX.X.X
```

### `release-ecr-public.yml`

End-to-end release pipeline that drafts a GitHub Release, builds and pushes a multi-arch (linux/amd64, linux/arm64) Docker image to Amazon ECR Public (`us-east-1`), signs the merged manifest with cosign, attaches an SPDX-JSON SBOM attestation, uploads a SLSA build provenance attestation, and publishes the Release. The `aws_role_arn` is assumed via OIDC. Runs in the `production` environment by default (override via the `environment` input).

The caller must provide a `Dockerfile` at its repo root, and register the `AWS_ROLE_ARN` secret in the `production` environment.

```yaml
name: Release

on:
  push:
    tags: ['v*.*.*']

permissions: {}

jobs:
  release:
    uses: iwamot/workflows/.github/workflows/release-ecr-public.yml@<sha> # vX.X.X
    permissions:
      contents: write
      id-token: write
      attestations: write
      artifact-metadata: write
    with:
      registry_image: public.ecr.aws/xxxxxxxx/namespace/repo
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

### `release-ghcr.yml`

End-to-end release pipeline that drafts a GitHub Release, builds and pushes a multi-arch (linux/amd64, linux/arm64) Docker image to `ghcr.io/<owner>/<repo>` using the caller's `GITHUB_TOKEN`, signs the merged manifest with cosign (keyless via OIDC), attaches an SPDX-JSON SBOM attestation, uploads a SLSA build provenance attestation, and publishes the Release. Runs in the `production` environment by default (override via the `environment` input).

The caller must provide a `Dockerfile` at its repo root. Optionally, register `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` in the `production` environment to enable `dhi.io` (Docker Hardened Images) login during builds.

```yaml
name: Release

on:
  push:
    tags: ['v*.*.*']

permissions: {}

jobs:
  release:
    uses: iwamot/workflows/.github/workflows/release-ghcr.yml@<sha> # vX.X.X
    permissions:
      contents: write
      packages: write
      id-token: write
      attestations: write
      artifact-metadata: write
    secrets:
      # Optional: enable dhi.io authentication during builds
      dockerhub_username: ${{ secrets.DOCKERHUB_USERNAME }}
      dockerhub_token: ${{ secrets.DOCKERHUB_TOKEN }}
```

### `release-homebrew-tap.yml`

End-to-end release pipeline for Go CLIs distributed via the `iwamot/homebrew-tap` cask tap: drafts a GitHub Release, runs `goreleaser` (binaries + cask file under `dist/`), attests SLSA build provenance for the released binaries, opens a cask-update PR against `iwamot/homebrew-tap` with auto-merge enabled, and publishes the Release. Runs in the `production` environment by default (override via the `environment` input).

The caller must provide a `.goreleaser.yaml` that emits binaries and a `<cask_name>.rb` cask file somewhere under `dist/` (GoReleaser's `homebrew_casks` writes to `dist/homebrew/Casks/<cask_name>.rb` by default), and register `HOMEBREW_TAP_APP_CLIENT_ID` / `HOMEBREW_TAP_APP_PRIVATE_KEY` (GitHub App credentials for the tap repo) in the `production` environment.

The tap repo (`iwamot/homebrew-tap`) and bot identity are hardcoded. The cask source is located via `find dist -name "<cask_name>.rb" -type f`, the tap destination is `Casks/<cask_name>.rb`, and the update branch is `cask-update-<cask_name>-<TAG>`. `cask_name` defaults to the caller repository name. The GitHub App token for the tap repo is minted from the passed secrets and does not consume caller permissions.

```yaml
name: Release

on:
  push:
    tags: ['v*']

permissions: {}

jobs:
  release:
    uses: iwamot/workflows/.github/workflows/release-homebrew-tap.yml@<sha> # vX.X.X
    permissions:
      contents: write
      id-token: write
      attestations: write
      artifact-metadata: write
    secrets:
      homebrew_tap_app_client_id: ${{ secrets.HOMEBREW_TAP_APP_CLIENT_ID }}
      homebrew_tap_app_private_key: ${{ secrets.HOMEBREW_TAP_APP_PRIVATE_KEY }}
```

### `release-only.yml`

Create a GitHub Release for the pushed tag with auto-generated notes. For repos that publish only a GitHub Release with no artifact distribution step (no Docker image, no package registry, no binary upload).

```yaml
name: Release

on:
  push:
    tags: ['v*']

permissions: {}

jobs:
  release:
    uses: iwamot/workflows/.github/workflows/release-only.yml@<sha> # vX.X.X
    permissions:
      contents: write
```

### `renovate.yml`

Runs Renovate with a GitHub App token. The caller must define a `production` environment containing `RENOVATE_APP_CLIENT_ID` and `RENOVATE_APP_PRIVATE_KEY` (GitHub App credentials).

Optional auto-detection:

- If the caller's `mise.toml` has `aqua:astral-sh/uv` under `[tools]`, its version is applied as `RENOVATE_CONSTRAINTS={"uv":"..."}`.
- If `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` are passed, `dhi.io` is configured via `RENOVATE_HOST_RULES`.

`mise` is allowed via `RENOVATE_ALLOWED_UNSAFE_EXECUTIONS`, so if the caller commits a `mise.lock`, Renovate keeps it in sync (`mise lock`) when updating tools in `mise.toml`.

```yaml
name: Renovate

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 * * * *'
  workflow_dispatch:
    inputs:
      log-level:
        description: 'Log level'
        default: 'info'
        type: choice
        options:
          - info
          - debug

permissions:
  contents: read

jobs:
  renovate:
    uses: iwamot/workflows/.github/workflows/renovate.yml@<sha> # vX.X.X
    with:
      log-level: ${{ inputs.log-level || 'info' }}
    secrets:
      RENOVATE_APP_CLIENT_ID: ${{ secrets.RENOVATE_APP_CLIENT_ID }}
      RENOVATE_APP_PRIVATE_KEY: ${{ secrets.RENOVATE_APP_PRIVATE_KEY }}
      # Optional: enable dhi.io authentication
      DOCKERHUB_USERNAME: ${{ secrets.DOCKERHUB_USERNAME }}
      DOCKERHUB_TOKEN: ${{ secrets.DOCKERHUB_TOKEN }}
```

### `validate.yml`

Expects a `mise.toml` with `min_version` at the caller's repository root and a `validate.sh` script.

```yaml
name: Validate

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

jobs:
  validate:
    uses: iwamot/workflows/.github/workflows/validate.yml@<sha> # vX.X.X
```

### `validate-with-coverage.yml`

Same as `validate.yml`, with an additional Codecov upload step using OIDC. Requires `id-token: write` at the caller's workflow level.

```yaml
name: Validate

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  validate:
    uses: iwamot/workflows/.github/workflows/validate-with-coverage.yml@<sha> # vX.X.X
```

## Validation

```bash
./validate.sh
```
