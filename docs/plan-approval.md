# Terraform Plan Approval Workflow

How infrastructure changes reach AWS: **no apply without a human reviewing
the exact plan that will be applied.** The mechanics live in
`.github/workflows/deploy.yml` (Issue #14); this document explains how the
pieces work and how to configure them (Issue #15, ADR-009).

## The flow

```
merge to main (terraform/** changed)
  └─ terraform-plan job          [environment: dev-infra-plan — unprotected]
       ├─ fmt-check · init · validate
       ├─ terraform plan -out=tfplan
       ├─ plan summary rendered on the workflow run page
       └─ tfplan uploaded as a workflow artifact
  └─ terraform-apply job         [environment: dev-infra — PROTECTED]
       ⏸  GitHub pauses the job: "Review pending deployments"
       │   reviewer reads the plan summary → Approve / Reject
       ├─ downloads the tfplan ARTIFACT
       ├─ terraform apply tfplan        ← applies the reviewed bytes
       └─ infrastructure verification (cluster ACTIVE, outputs)
```

## How GitHub Environments work

An **Environment** is a named deployment target (`dev-infra`) that jobs
opt into with `environment: <name>`. Environments carry two things:

1. **Protection rules.** The one we use is **required reviewers**: when a
   job targeting the environment starts, GitHub suspends it and notifies
   the reviewers. The job's steps do not run — and its OIDC token is not
   issued — until someone with reviewer rights clicks *Approve* on the
   run page. Rejection cancels the job. The approval (who, when) is
   recorded on the run: an audit trail for every apply.

2. **Scoped secrets/variables.** Values attached to an environment are
   only visible to jobs running in it — another isolation layer we get
   for free.

## Why the approval is trustworthy (three properties)

**1. The reviewed plan is the applied plan.** The plan job uploads
`tfplan` as an artifact; the apply job downloads and runs
`terraform apply tfplan`. Terraform refuses to apply a plan if the state
has changed underneath it — so what the reviewer read is bit-for-bit what
executes, or nothing executes.

**2. Approval gates the credentials, not just the job.** The
`gha-terraform` IAM role's trust policy (iam module, ADR-008) only accepts
OIDC tokens claiming `environment:dev-infra` or `environment:dev-infra-plan`.
The apply job's token with the `dev-infra` claim doesn't exist until a
reviewer approves. Even a compromised workflow file cannot skip the gate
and keep AWS access: no approval, no credentials.

**3. Plan is unprivileged-by-protection.** Plan runs in `dev-infra-plan`
(no reviewers) because reading state and computing a diff should not
require a human; only *mutating* infrastructure does. Two environments,
one role, protection asymmetry by design.

## One-time configuration (scripted via gh CLI)

```bash
REPO=damilarewilliams/varonis-restaurant-api
cd "$(git rev-parse --show-toplevel)"

# Actions variables — role ARNs require a completed terraform apply;
# re-run those two lines after the first apply if needed.
gh variable set AWS_REGION -R "$REPO" -b "us-east-1"
gh variable set ECR_REPOSITORY -R "$REPO" -b "varonis-restaurant-api-dev"
gh variable set AWS_TERRAFORM_ROLE_ARN -R "$REPO" \
  -b "$(terraform -chdir=terraform/environments/dev output -raw gha_terraform_role_arn)"
gh variable set AWS_DELIVERY_ROLE_ARN -R "$REPO" \
  -b "$(terraform -chdir=terraform/environments/dev output -raw gha_delivery_role_arn)"
gh variable list -R "$REPO"

# Environments: plan (unprotected) and apply (required reviewer = you).
gh api -X PUT "repos/$REPO/environments/dev-infra-plan"
USER_ID=$(gh api user -q .id)
gh api -X PUT "repos/$REPO/environments/dev-infra" \
  --input - <<EOF
{"reviewers": [{"type": "User", "id": $USER_ID}]}
EOF
```

Note: on a personal repository the sole maintainer can approve their own
deployments; in an organization the reviewer set would exclude the author.

Remaining UI step: Settings → Rules → main ruleset → **Bypass list** →
add "GitHub Actions" (the values-bump bot commit, see below).

## Branch protection and the GitOps bot (ADR-009)

`main` is protected: PRs required, CI status checks required. That raises
a conflict — the pipeline itself pushes the `values.yaml` bump commit
directly to `main`. Resolution: a **ruleset bypass for the GitHub Actions
bot** (Settings → Rules → the main ruleset → Bypass list → add
`github-actions[bot]`). The bypass is narrow (that identity only), fully
audited (bot commits are visibly attributed), and the bot only ever writes
one file via the reviewed workflow. The alternative — the bot opening
auto-merged PRs — adds latency and PR noise for zero additional control,
since the workflow content that drives the bot is itself PR-reviewed.

## Rejecting a plan

Click *Reject* on the pending deployment. The apply job cancels; nothing
was applied; the tfplan artifact expires (5 days). Fix forward with a new
PR — the next merge produces a fresh plan.
