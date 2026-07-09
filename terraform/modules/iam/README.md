# iam module

Least-privilege identity for every principal in the system. No static AWS
access keys exist anywhere — pods authenticate via IRSA, CI via GitHub OIDC
federation (ADR-008).

## Principals and their permissions

| Principal | Auth path | Permissions |
|-----------|-----------|-------------|
| API pod | IRSA (cluster OIDC) | DynamoDB read on the restaurants table only |
| ARC runner pod | IRSA (cluster OIDC) | `eks:DescribeCluster` + Kubernetes VIEW scoped to the app namespace (EKS access entry) |
| CI delivery job | GitHub OIDC, `main` branch only | ECR auth + push to the project repository only |
| CI terraform job | GitHub OIDC, protected Environment only | PowerUserAccess + IAM restricted to `<project>-<env>-*` roles |

## Design decisions

- **IRSA trust is per-service-account.** The `sub` condition names one
  namespace + service account; no other pod can assume the role even from
  the same node.
- **Runner verifies, ArgoCD mutates.** The runner's Kubernetes access is
  VIEW, namespaced — rollout status and health checks read state; only
  ArgoCD applies changes. A compromised CD job cannot modify the cluster.
- **Branch/environment-scoped CI trust.** The delivery role is assumable
  only from `refs/heads/main`; the terraform role only from jobs in the
  protected GitHub Environment (`dev-infra`) — the same gate that enforces
  human plan approval (Issue #15). Fork PRs can assume neither.
- **Terraform role is broad but bounded.** It provisions everything, so
  PowerUserAccess is honest; IAM (which PowerUser denies) is re-granted
  only on project-prefixed roles — CI can manage this stack's identities
  and cannot touch any other role in the account.
- **`ecr:GetAuthorizationToken` on `*`** is an AWS constraint: the action
  does not support resource scoping.

## Inputs / Outputs

See variables.tf and outputs.tf — inputs wire in the eks and dynamodb
module outputs plus the GitHub repository; outputs feed Helm values
(ServiceAccount annotations) and GitHub Actions variables (role ARNs).

## Usage

```hcl
module "iam" {
  source = "../../modules/iam"

  project             = var.project
  environment         = var.environment
  cluster_name        = module.eks.cluster_name
  oidc_provider_arn   = module.eks.oidc_provider_arn
  oidc_provider_url   = module.eks.oidc_provider_url
  dynamodb_table_arns = [module.dynamodb.table_arn]
  github_repository   = "damilarewilliams/varonis-restaurant-api"
}
```
