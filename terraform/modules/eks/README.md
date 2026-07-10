# eks module

Managed EKS control plane, managed node group in private subnets, OIDC
provider for IRSA, and core add-ons. Implements
[docs/architecture.md](../../../docs/architecture.md#eks-architecture).

## Design decisions

- **Managed node groups** over self-managed: AWS owns AMI patching and
  drain-on-upgrade; this workload needs nothing custom from nodes.
- **Nodes in private subnets only.** No public IPs; egress via NAT or VPC
  endpoints (networking module).
- **API access entries (`authentication_mode = "API"`)** instead of the
  legacy aws-auth ConfigMap - auditable IAM-native access;
  `bootstrap_cluster_creator_admin_permissions` keeps Terraform able to
  manage in-cluster releases (ArgoCD, ARC) after creation.
- **Node role carries zero application permissions.** Pods get AWS access
  through IRSA roles (Issue #10) bound to service accounts via the OIDC
  provider created here - node-role permissions would leak to every pod.
- **Control plane logs** (api, audit, authenticator) ship to CloudWatch -
  the API-server audit trail required by the logging architecture.
- **Public endpoint + CIDR allowlist in dev** (variable): lets GitHub-hosted
  runners and your laptop reach the API without VPN; flip
  `endpoint_public_access=false` for the hardened private-only posture.
- **`ignore_changes` on desired_size**: a future autoscaler owns node count;
  Terraform owns min/max bounds.
- **EBS CSI omitted deliberately** - no persistent volumes in this system;
  install it (plus its IRSA role) only when a need exists.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project / environment | Naming and tags | - |
| vpc_id | VPC for the cluster | - |
| private_subnet_ids | Subnets for control plane ENIs + nodes | - |
| cluster_version | Kubernetes minor version | `1.32` |
| endpoint_public_access | Public API endpoint (dev convenience) | `true` |
| endpoint_public_access_cidrs | Allowlist for public endpoint | `0.0.0.0/0` |
| cluster_log_types | Control plane log types | api, audit, authenticator |
| node_instance_types | Node group instance types | `t3.medium` |
| node_min/desired/max_size | Autoscaling bounds | 2 / 2 / 4 |
| node_disk_size | Root volume GiB | `20` |

## Outputs

cluster_name, cluster_endpoint, cluster_certificate_authority_data,
cluster_security_group_id, oidc_provider_arn, oidc_provider_url,
node_role_arn.

## Usage

```hcl
module "eks" {
  source = "../../modules/eks"

  project            = var.project
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
}
```
