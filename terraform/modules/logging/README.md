# logging module

CloudWatch log groups with KMS encryption, bounded retention, and least-privilege writer/reader policies.

Implemented in [Issue #11](https://github.com/damilarewilliams/varonis-restaurant-api/issues/11).

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project | Project identifier used in names and tags | string | yes |
| environment | Environment name (dev, staging, prod) | string | yes |

Further inputs, outputs, and design decisions are documented when the
module is implemented.
