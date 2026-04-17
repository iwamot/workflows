# workflows

iwamot's shared reusable GitHub Actions workflows.

## Workflows

| Workflow | Purpose |
|----------|---------|
| `dependency-review.yml` | Run `actions/dependency-review-action` on pull requests. |

## Usage

In your repository's `.github/workflows/dependency-review.yml`:

```yaml
name: 'Dependency review'
on:
  pull_request:
    branches: [main]

permissions:
  contents: read
  pull-requests: write

jobs:
  dependency-review:
    uses: iwamot/workflows/.github/workflows/dependency-review.yml@<sha> # v0.1.0
```

Pin to a commit SHA with a version comment so Renovate can track updates.

## Validation

```bash
./validate.sh
```
