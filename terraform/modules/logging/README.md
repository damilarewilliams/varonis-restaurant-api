# logging module

The encrypted, access-controlled destination for the system's logs.
Masking of sensitive fields already happened inside the application
(app/core/logging.py) - this module guarantees what happens after.

## Design decisions

- **KMS-encrypted log groups** using the dedicated logs CMK (kms module,
  `allow_cloudwatch_logs = true`). Logs are sensitive data; the data key
  and logs key are separate blast radii.
- **Bounded retention (default 30 days).** Unbounded log retention is
  unbounded exposure and unbounded cost.
- **EKS control-plane log group lives in the eks module**, created there
  before the cluster (implicit creation by EKS would leave it unencrypted
  with no retention). It cannot live here without a module cycle: this
  module consumes eks outputs for the shipper role.
- **Write-only shipper identity.** The Fluent Bit IRSA role can create
  streams and put events in exactly one log group. It cannot read logs
  back, cannot touch other groups, cannot change retention.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project / environment | Naming and tags | - |
| kms_key_arn | Logs CMK | - |
| retention_in_days | Log retention | `30` |
| oidc_provider_arn / url | Cluster OIDC (shipper IRSA) | - |
| shipper_namespace / service_account | Fluent Bit identity | `logging` / `fluent-bit` |

## Outputs

app_log_group_name/arn (Fluent Bit config), shipper_role_arn
(ServiceAccount annotation).
