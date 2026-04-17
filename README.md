# workflows

iwamot's shared reusable GitHub Actions workflows.

## Workflows

| Workflow | Purpose |
|----------|---------|
| `dependabot-auto-merge.yml` | Enable auto-merge for non-major Dependabot PRs. |
| `dependency-review.yml` | Run `actions/dependency-review-action` on pull requests. |

## Usage

Call a reusable workflow at the job level:

```yaml
jobs:
  dependency-review:
    uses: iwamot/workflows/.github/workflows/dependency-review.yml@<sha> # vX.X.X
```

The caller provides the triggers and workflow-level `permissions`.

## Validation

```bash
./validate.sh
```
