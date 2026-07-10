# networking module

VPC with a public/private subnet pair per Availability Zone, Internet
Gateway, NAT gateway(s), and VPC endpoints. Implements the network design in
[docs/architecture.md](../../../docs/architecture.md#aws-network-architecture).

## Design decisions

- **Private-only workloads.** EKS nodes, pods, ArgoCD, and runners live in
  private subnets with no public IPs. Only load balancers and NAT gateways
  occupy public subnets.
- **`single_nat_gateway` flag.** Production posture is one NAT per AZ
  (AZ-fault-isolated egress, ~$32/mo each); dev flips one flag to share a
  single NAT. The architecture stays identical - only the redundancy changes.
- **/20 subnets.** The EKS VPC CNI gives every pod a VPC IP, so subnets are
  sized for pod density (4,091 IPs each), not node count.
- **VPC endpoints.** S3 + DynamoDB gateway endpoints are free and always on;
  ECR (api/dkr) + CloudWatch Logs interface endpoints keep image pulls and
  log shipping off NAT (cost + attack surface), gated by
  `enable_interface_endpoints` because they bill hourly per AZ.
- **EKS subnet tags.** `kubernetes.io/role/elb` / `internal-elb` +
  `kubernetes.io/cluster/<name>` enable AWS Load Balancer Controller subnet
  discovery. `cluster_name` is passed as a plain string to avoid a
  networking->eks dependency cycle.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| project | Project identifier for names/tags | string | - |
| environment | Environment name | string | - |
| vpc_cidr | VPC CIDR block | string | `10.0.0.0/16` |
| az_count | AZs to span (2–4) | number | `3` |
| single_nat_gateway | Shared NAT (dev) vs per-AZ (prod) | bool | `false` |
| enable_interface_endpoints | Create ECR/Logs interface endpoints | bool | `true` |
| cluster_name | EKS cluster name for subnet discovery tags | string | `""` |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_cidr | VPC CIDR block |
| public_subnet_ids | Public subnet IDs |
| private_subnet_ids | Private subnet IDs |
| private_route_table_ids | Private route table IDs |
| nat_public_ips | NAT gateway public IPs |

## Usage

```hcl
module "networking" {
  source = "../../modules/networking"

  project            = var.project
  environment        = var.environment
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 3
  single_nat_gateway = true # dev cost mode
  cluster_name       = "${var.project}-${var.environment}"
}
```
