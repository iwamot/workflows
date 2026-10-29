#!/bin/bash
set -e

# mise
eval "$(mise activate bash)"
mise fmt
mise install

# Shared lint tasks
mise run gha-lint
mise run shell-lint

# Verify the workflow's direct and transitive action pins against GitHub.
GH_TOKEN="${GITHUB_TOKEN:-$(gh auth token)}" gh-actions-lock --verify .github/workflows/validate.yml

# Check for uncommitted changes
git diff --exit-code
