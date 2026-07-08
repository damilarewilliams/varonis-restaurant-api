# ecr module

Private ECR repository with scan-on-push, immutable tags, and a lifecycle policy to bound storage.

Implemented in [Issue #8](https://github.com/damilarewilliams/varonis-restaurant-api/issues/8).

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project | Project identifier used in names and tags | string | yes |
| environment | Environment name (dev, staging, prod) | string | yes |

Further inputs, outputs, and design decisions are documented when the
module is implemented.
