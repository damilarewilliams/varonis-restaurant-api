# iam module

Least-privilege IAM: IRSA roles for the API pod (DynamoDB read) and ARC runners (CD verification), plus the GitHub OIDC role for CI.

Implemented in [Issue #10](https://github.com/damilarewilliams/varonis-restaurant-api/issues/10).

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project | Project identifier used in names and tags | string | yes |
| environment | Environment name (dev, staging, prod) | string | yes |

Further inputs, outputs, and design decisions are documented when the
module is implemented.
