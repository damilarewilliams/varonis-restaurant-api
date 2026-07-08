# networking module

VPC, public/private subnets across 3 AZs, NAT gateway(s), Internet Gateway, and VPC endpoints (ECR, S3, CloudWatch Logs, DynamoDB).

Implemented in [Issue #6](https://github.com/damilarewilliams/varonis-restaurant-api/issues/6).

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project | Project identifier used in names and tags | string | yes |
| environment | Environment name (dev, staging, prod) | string | yes |

Further inputs, outputs, and design decisions are documented when the
module is implemented.
