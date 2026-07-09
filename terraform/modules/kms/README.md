# kms module

One customer-managed KMS key (CMK) per purpose, with annual rotation and a
safe deletion window. Instantiated per concern (`data`, `logs`) so each has
its own access policy and blast radius — a compromise of the logs key never
exposes the data key.

## Design decisions

- **CMK over AWS-managed keys** where the data is sensitive (DynamoDB
  restaurant data, CloudWatch logs): auditable usage in CloudTrail,
  revocable grants, policy control. Non-sensitive material (ECR images)
  stays on free AWS-managed encryption — see the ecr module README.
- **Root-admin statement** is mandatory boilerplate: a CMK whose policy
  locks out the account is unrecoverable by design.
- **`allow_cloudwatch_logs` flag** adds the service-principal grant that
  encrypted log groups require, scoped by encryption context to this
  account's log groups only.
- **Rotation on, 7-30 day deletion window** (default 7 in dev).

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project / environment | Naming and tags | — |
| purpose | What the key encrypts; forms the alias | — |
| allow_cloudwatch_logs | Grant logs service use of key | `false` |
| deletion_window_in_days | Deletion recovery window | `7` |

## Outputs

key_arn, key_id, alias_name.

## Usage

```hcl
module "kms_data" {
  source      = "../../modules/kms"
  project     = var.project
  environment = var.environment
  purpose     = "data"
}
```
