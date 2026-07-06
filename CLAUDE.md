# Claude Code Instructions

## Before creating a PR

Always run CI and confirm all checks pass before opening a pull request.

1. Run `bin/ci` (preferred when Ruby and MySQL are available in the environment)
2. If that fails due to missing dependencies, run `bin/ci-docker` (runs the same checks via Docker Compose)

Do not open a PR until CI passes. If CI fails, fix the issues and re-run until it succeeds.

If you changed views or UI, also run:

```bash
bin/rails db:test:prepare test:system
```

## Pull requests from issues

When creating a PR from an issue, reference the issue in the PR body (for example `Closes #123`).
