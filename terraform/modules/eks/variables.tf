variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC to place the cluster in"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the control plane ENIs and worker nodes"
  type        = list(string)
}

variable "cluster_version" {
  description = "Kubernetes version for the cluster (minor version; AWS manages patches)"
  type        = string
  default     = "1.32"
}

variable "endpoint_public_access" {
  description = <<-EOT
    Expose the cluster API endpoint publicly. Dev default true so
    GitHub-hosted runners can run Terraform/kubectl without VPN
    infrastructure - restricted by endpoint_public_access_cidrs.
    Hardened posture: false (private endpoint only).
  EOT
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Narrow this to office/CI IPs where possible."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "log_group_kms_key_arn" {
  description = <<-EOT
    CMK for the control-plane log group. The group is created HERE, before
    the cluster: if EKS creates it implicitly instead, it gets no
    encryption and no retention. Empty string = unencrypted (not
    recommended; dev passes the logs CMK).
  EOT
  type        = string
  default     = ""
}

variable "log_retention_in_days" {
  description = "Retention for the control-plane log group"
  type        = number
  default     = 30
}

variable "cluster_log_types" {
  description = "Control plane log types shipped to CloudWatch (audit trail for the API server)"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "node_instance_types" {
  description = "Instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Node root volume size (GiB)"
  type        = number
  default     = 20
}
