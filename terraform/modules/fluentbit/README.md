# fluentbit module

Deploys AWS for Fluent Bit as a DaemonSet - the shipper leg of the
logging pipeline (app masks in-process → stdout → **Fluent Bit** →
CMK-encrypted CloudWatch group).

## Design decisions

- **Own namespace + IRSA service account** (not chart-created) so the
  annotation matches the logging module's write-only trust policy
  exactly: `system:serviceaccount:logging:fluent-bit`.
- **App-namespace logs only.** The input path filters to
  `restaurant-api` containers; platform namespaces are out of scope for
  this group and the shipper's single-group write permission.
- **`autoCreateGroup: false`.** The group is Terraform-managed with
  encryption and retention; the role can't create groups, so
  misconfiguration fails loudly instead of creating an unencrypted
  group silently.
- **DaemonSet, not sidecar**: one collector per node beats one per pod
  on both resources and operational surface.

## Inputs / Outputs

project/environment, aws_region, log_group_name + shipper_role_arn
(logging module outputs), namespace/service_account (must match IRSA
trust), app_namespace → namespace.
