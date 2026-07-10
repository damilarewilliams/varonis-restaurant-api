# Contributing Guide

This repository follows a **feature-branch workflow**. No commits land on `main` directly.

## Workflow

1. Pick a GitHub Issue from the [project board](https://github.com/damilarewilliams/varonis-restaurant-api/issues).
2. Create a feature branch from an up-to-date `main`:

   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/<short-description>
   ```

3. Commit work in small, logical units (see commit conventions below).
4. Push the branch and open a Pull Request into `main`.
5. Link the PR to its issue with `Closes #<issue-number>` in the description.
6. Merge only after CI passes and review is complete. Prefer **squash merge** to keep `main` history linear and one-commit-per-issue.
7. Delete the feature branch after merge.

## Branch naming

| Prefix      | Use for                          |
|-------------|----------------------------------|
| `feature/`  | New functionality or infra       |
| `fix/`      | Bug fixes                        |
| `docs/`     | Documentation-only changes       |
| `ci/`       | Pipeline changes                 |

## Commit message convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <imperative summary>

<body: what and why, not how>
```

Types: `feat`, `fix`, `docs`, `ci`, `chore`, `refactor`, `test`.
Scopes: `app`, `terraform`, `helm`, `ci`, `docs`, `repo`.

Example:

```
feat(terraform): add reusable VPC module with private EKS subnets

Provisions a 3-AZ VPC with public/private subnet tiers and NAT
gateways so EKS worker nodes never receive public IPs.
```

## Pull Request rules

- One issue per PR. Keep PRs reviewable (< ~500 lines where possible).
- Fill in the PR template completely.
- CI must be green before merge.
- Never commit secrets, `.tfstate`, `.tfvars`, or kubeconfig files - `.gitignore` blocks these, do not force-add them.

## Decision log

Any non-obvious technical choice (tool, pattern, trade-off) gets an entry in
[`docs/decision-log.md`](docs/decision-log.md) in the same PR that introduces it.
