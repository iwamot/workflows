# workflows

iwamot's shared reusable GitHub Actions workflows.

## Workflows

| Workflow | Purpose |
|----------|---------|
| `compatibility-go.yml` | Run the caller's `compatibility.sh` across a matrix of Go versions. |
| `compatibility-node.yml` | Run the caller's `compatibility.sh` across a matrix of Node.js versions. |
| `compatibility-python.yml` | Run the caller's `compatibility.sh` across a matrix of Python versions. |
| `dependabot-auto-merge.yml` | Enable auto-merge for non-major Dependabot PRs. |
| `dependency-review.yml` | Run `actions/dependency-review-action` on pull requests. |
| `publish-ecr-public.yml` | Build a multi-arch Docker image, push to Amazon ECR Public, sign with cosign, and attach an SBOM attestation. |
| `publish-ghcr.yml` | Build a multi-arch Docker image, push to `ghcr.io/<owner>/<repo>`, sign with cosign, and attach an SBOM attestation. |
| `renovate.yml` | Run Renovate with GitHub App authentication. |
| `validate.yml` | Run `validate.sh` under mise. |
| `validate-with-coverage.yml` | Run `validate.sh` under mise and upload coverage to Codecov. |

## Usage

Each workflow is invoked from a caller workflow via `uses:` at the job level. The caller defines its own triggers and workflow-level `permissions`.

### `compatibility-go.yml`

Run a caller-provided `compatibility.sh` script under each Go version in the matrix. The matrix Go version is plumbed to mise via the `MISE_GO_VERSION` environment variable (set at the job level), so the script itself does not need to thread the version through any command. What "compatibility" means (unit tests, packaging smoke test, end-to-end against fixtures, or any combination) is decided by the caller.

The `mise` binary is preinstalled on the runner (no tools installed), so the caller's `compatibility.sh` is responsible for activating mise and installing whatever it needs from `mise.toml`. A typical script exercises the `go install` path in an isolated `GOBIN` and runs the resulting binary against fixtures:

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

The `go-versions` input is a JSON-encoded array of version strings.

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

Run a caller-provided `compatibility.sh` script under each Node.js version in the matrix. The matrix Node.js version is plumbed to mise via the `MISE_NODE_VERSION` environment variable (set at the job level), so the script itself does not need to thread the version through any command. What "compatibility" means (unit tests, packaging smoke test, end-to-end against fixtures, or any combination) is decided by the caller.

The `mise` binary is preinstalled on the runner (no tools installed), so the caller's `compatibility.sh` is responsible for activating mise and installing whatever it needs from `mise.toml`. A typical script builds the package once and exercises the packed tarball in an isolated directory:

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

The `node-versions` input is a JSON-encoded array of version strings.

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

Run a caller-provided `compatibility.sh` script under each Python version in the matrix. The matrix Python version is plumbed to `uv` via the `UV_PYTHON` environment variable (set at the job level), so the script itself does not need to thread the version through any command. What "compatibility" means (unit tests, packaging smoke test, end-to-end against fixtures, or any combination) is decided by the caller.

The `mise` binary is preinstalled on the runner (no tools installed), so the caller's `compatibility.sh` is responsible for activating mise and installing whatever it needs from `mise.toml`. Use the canonical tool name that matches your `mise.toml` key (e.g. `aqua:astral-sh/uv`) — a short alias like `mise install uv` may install the binary but leave the shim inactive in a clean environment. A typical script builds the wheel once and exercises it under the matrix Python in an isolated environment:

```bash
#!/bin/bash
set -e

eval "$(mise activate bash)"
mise install aqua:astral-sh/uv

uv build --wheel --out-dir dist
uv run --isolated --no-project --with ./dist/*.whl <cli> <fixture>
```

The `python-versions` input is a JSON-encoded array of version strings.

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

### `dependabot-auto-merge.yml`

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

### `publish-ecr-public.yml`

Same build/sign/SBOM pipeline as `publish-ghcr.yml`, but pushes to Amazon ECR Public (`us-east-1`) using OIDC to assume the IAM role passed via `aws_role_arn`.

Requires `id-token: write` at the caller's workflow level. A `production` environment is used by default (override via the `environment` input).

Required:

- `registry_image` input: Full ECR Public image URI (e.g. `public.ecr.aws/xxxxxxxx/namespace/repo`).
- `aws_role_arn` secret: IAM role ARN to assume via OIDC.

```yaml
name: Publish

on:
  push:
    tags: ['v*.*.*']

permissions:
  contents: read
  id-token: write

jobs:
  publish:
    uses: iwamot/workflows/.github/workflows/publish-ecr-public.yml@<sha> # vX.X.X
    with:
      registry_image: public.ecr.aws/xxxxxxxx/namespace/repo
    secrets:
      aws_role_arn: ${{ secrets.AWS_ROLE_ARN }}
```

### `publish-ghcr.yml`

Build a multi-arch Docker image (linux/amd64, linux/arm64), push it to `ghcr.io/<owner>/<repo>`, then sign with cosign (keyless via OIDC) and attach a SPDX-JSON SBOM attestation. Uses the caller's `GITHUB_TOKEN` for GHCR login — no registry credentials required.

Requires `packages: write` and `id-token: write` at the caller's workflow level. A `production` environment is used by default (override via the `environment` input).

Optional behavior:

- If `dockerhub_username` / `dockerhub_token` secrets are passed, `dhi.io` (Docker Hardened Images) login is performed before the build.

```yaml
name: Publish

on:
  push:
    tags: ['v*.*.*']

permissions:
  contents: read
  packages: write
  id-token: write

jobs:
  publish:
    uses: iwamot/workflows/.github/workflows/publish-ghcr.yml@<sha> # vX.X.X
    secrets:
      # Optional: enable dhi.io authentication during builds
      dockerhub_username: ${{ secrets.DOCKERHUB_USERNAME }}
      dockerhub_token: ${{ secrets.DOCKERHUB_TOKEN }}
```

### `renovate.yml`

Requires a `production` environment on the caller with `RENOVATE_APP_ID` and `RENOVATE_PRIVATE_KEY` secrets (GitHub App credentials used to mint a Renovate access token).

Optional behavior:

- If the caller's repository has a `mise.toml` with `aqua:astral-sh/uv` in its `[tools]` section, its version is auto-applied to Renovate as `RENOVATE_CONSTRAINTS={"uv":"..."}`.
- If `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets are passed, `dhi.io` Docker Hub authentication is configured via `RENOVATE_HOST_RULES`.

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
      RENOVATE_APP_ID: ${{ secrets.RENOVATE_APP_ID }}
      RENOVATE_PRIVATE_KEY: ${{ secrets.RENOVATE_PRIVATE_KEY }}
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
