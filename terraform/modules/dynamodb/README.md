# dynamodb module

DynamoDB table for restaurant data: on-demand capacity, KMS encryption at rest, point-in-time recovery.

Implemented in [Issue #9](https://github.com/damilarewilliams/varonis-restaurant-api/issues/9).

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project | Project identifier used in names and tags | string | yes |
| environment | Environment name (dev, staging, prod) | string | yes |

Further inputs, outputs, and design decisions are documented when the
module is implemented.
