# eks module

EKS cluster with managed node groups in private subnets, cluster add-ons, and the OIDC provider that enables IRSA.

Implemented in [Issue #7](https://github.com/damilarewilliams/varonis-restaurant-api/issues/7).

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project | Project identifier used in names and tags | string | yes |
| environment | Environment name (dev, staging, prod) | string | yes |

Further inputs, outputs, and design decisions are documented when the
module is implemented.
