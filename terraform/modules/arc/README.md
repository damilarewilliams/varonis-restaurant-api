# arc module

actions-runner-controller (ADR-005): ephemeral, scale-from-zero
self-hosted runners for CD jobs only. The scale set name (`arc-cd`) is
the `runs-on` label.

## Design decisions

- **CD jobs only** (ADR-005): CI/Terraform/build stay on GitHub-hosted
  runners — no circular dependency on the cluster the pipeline manages.
- **Own namespace + service account** (not chart-created) so the IRSA
  annotation matches the iam module's trust policy exactly
  (`system:serviceaccount:arc-runners:arc-runner`).
- **minRunners 0**: a fresh pod per job, zero idle cost, no state leakage.
- **PAT via sensitive TF_VAR** (`TF_VAR_arc_github_token`), never
  committed. A GitHub App is the lower-privilege production upgrade.

## Inputs / Outputs

github_repository_url, github_token (sensitive), runner_role_arn,
runner_scale_set_name (`arc-cd`), max_runners (3) → runner_label.
