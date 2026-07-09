# dynamodb module

Restaurant catalog table: on-demand billing, CMK encryption, point-in-time
recovery, deletion protection.

## Design decisions

- **PAY_PER_REQUEST**: small spiky catalog — no capacity planning, zero
  idle cost. Provisioned capacity only wins under sustained predictable
  load.
- **Simple `id` hash key, no GSIs yet.** The API scans with filters over a
  bounded catalog (trade-off documented in app/repositories/dynamodb.py);
  a `style` GSI is the documented evolution, added when data justifies it
  rather than speculatively.
- **CMK encryption** (kms module) instead of the AWS-owned default key:
  auditable, revocable — restaurant data is the system's actual data
  asset.
- **PITR on** (35-day any-second restore) and **deletion protection on**
  by default; dev may relax deletion protection to keep `terraform
  destroy` usable.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project / environment | Naming and tags | — |
| table_suffix | Full name = project-env-suffix | `restaurants` |
| kms_key_arn | CMK for encryption at rest | — |
| enable_point_in_time_recovery | 35-day continuous backup | `true` |
| deletion_protection | Block table deletion | `true` |

## Outputs

table_name (→ APP_DYNAMODB_TABLE), table_arn (→ IRSA policy, Issue #10).

## Usage

```hcl
module "dynamodb" {
  source      = "../../modules/dynamodb"
  project     = var.project
  environment = var.environment
  kms_key_arn = module.kms_data.key_arn
}
```
