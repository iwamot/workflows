# workflows

iwamot's shared reusable GitHub Actions workflows.

## Workflows

| Workflow | Purpose |
|----------|---------|
| `dependabot-auto-merge.yml` | Enable auto-merge for non-major Dependabot PRs. |
| `dependency-review.yml` | Run `actions/dependency-review-action` on pull requests. |
| `renovate.yml` | Run Renovate with GitHub App authentication. |

## Usage

Each workflow is invoked from a caller workflow via `uses:` at the job level. The caller defines its own triggers and workflow-level `permissions`.

### `dependabot-auto-merge.yml`

```yaml
name: Dependabot auto-merge

on: pull_request

permissions:
  contents: write
  pull-requests: write

jobs:
  dependabot:
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

### `renovate.yml`

Requires a `production` environment on the caller with `RENOVATE_APP_ID` and `RENOVATE_PRIVATE_KEY` secrets (GitHub App credentials used to mint a Renovate access token).

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
```

## Validation

```bash
./validate.sh
```
