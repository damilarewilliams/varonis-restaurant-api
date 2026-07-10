# Terraform

Infrastructure as Code for the restaurant recommendation platform.

## Layout

```
terraform/
├── environments/          # Composition roots - one per environment
│   └── dev/               #   wires modules together with env-specific values
└── modules/               # Reusable building blocks - no environment opinions
    ├── networking/        # VPC, subnets, NAT, VPC endpoints        (Issue #6)
    ├── eks/               # Cluster, node groups, OIDC/IRSA         (Issue #7)
    ├── ecr/               # Container registry                      (Issue #8)
    ├── dynamodb/          # Restaurant data table                   (Issue #9)
    ├── iam/               # Least-privilege roles and policies      (Issue #10)
    ├── logging/           # CloudWatch log groups, retention        (Issue #11)
    └── kms/               # Customer-managed encryption keys        (Issue #9/#11)
```

**Why environments/ + modules/:** modules encode *how* to build a thing
(reusable, tested, no hardcoded env values); environments encode *what this
env looks like* (CIDRs, sizes, feature flags). Adding staging/prod later means
a new environments/ folder reusing identical modules - not copied resources.

## Conventions

Every module contains exactly: `main.tf` (resources), `variables.tf` (typed
inputs with descriptions), `outputs.tf` (documented outputs), `README.md`
(purpose, design decisions, usage). Environment roots add `versions.tf`,
`providers.tf`, `backend.tf`. Formatting is enforced by `terraform fmt -check`
in CI; naming is `${var.project}-${var.environment}-<thing>`.

## Remote state (ADR-006)

State lives in S3 (`varonis-restaurant-api-tfstate`, versioned, KMS-encrypted,
public-access-blocked) with S3-native lockfile locking - no DynamoDB lock
table needed on Terraform >= 1.10. The bucket is the single bootstrap
exception created via CLI (commands in `environments/dev/backend.tf`);
everything else is Terraform-managed.

## Working locally

```bash
cd terraform/environments/dev
terraform init          # downloads providers, connects to remote state
terraform fmt -check -recursive ../..
terraform validate
terraform plan          # never apply locally once CI owns apply (Issue #14)
```
