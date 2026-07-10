# Deployment

How change reaches production, and how a fresh environment comes up.

## Day-to-day: how a deploy happens

You never deploy manually. Merge to `main`:

1. App paths changed → pipeline builds the image, Trivy-gates it, pushes
   to ECR (`<sha>` tag), commits the new tag to
   `helm/restaurant-api/values.yaml` (`[skip ci]`).
2. ArgoCD detects the commit, re-renders the chart, rolls the Deployment
   (maxSurge 1 / maxUnavailable 0 — zero downtime).
3. The cd-verify job (in-cluster ARC runner) waits for convergence to the
   exact SHA, rollout completion, health/readiness, and smoke tests.

Infra paths changed → plan → **human approval** (dev-infra environment)
→ apply of the reviewed artifact → verification. Details:
[plan-approval.md](plan-approval.md).

## Rollback

```bash
git revert <values-bump-commit>   # then push (via PR or as the bot)
```

ArgoCD converges the cluster back to the previous image. ECR's immutable
tags guarantee the old tag is byte-identical to what ran before. No
kubectl, no helm rollback — Git is the deployment history.

## First-time bootstrap (fresh AWS account)

```bash
# 1. State bucket — the single out-of-Terraform resource (ADR-006);
#    commands documented in terraform/environments/dev/backend.tf
# 2. Provision everything:
cd terraform/environments/dev
terraform init
export TF_VAR_arc_github_token=<PAT>   # ARC runner registration
terraform plan -out=tfplan && terraform apply tfplan   # ~15 min (EKS)
# 3. Seed the catalog:
python scripts/seed_dynamodb.py --table "$(terraform output -raw dynamodb_table_name)"
# 4. Point CI at the real roles:
gh variable set AWS_TERRAFORM_ROLE_ARN -R <repo> -b "$(terraform output -raw gha_terraform_role_arn)"
gh variable set AWS_DELIVERY_ROLE_ARN  -R <repo> -b "$(terraform output -raw gha_delivery_role_arn)"
# 5. First app deploy: merge any app change; the pipeline does the rest.
```

After bootstrap, the pipeline owns applies; local `terraform apply` is
for bootstrap and break-glass only.

## Decommissioning

See [teardown.md](teardown.md) — ordered destroy with guardrails.
