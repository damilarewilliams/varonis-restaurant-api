variable "project" {
  description = "Project identifier used in names and tags"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "repo_url" {
  description = "Git repository ArgoCD watches (the GitOps source of truth)"
  type        = string
}

variable "target_revision" {
  description = "Branch/tag ArgoCD tracks"
  type        = string
  default     = "main"
}

variable "chart_path" {
  description = "Path to the application Helm chart within the repository"
  type        = string
  default     = "helm/restaurant-api"
}

variable "app_namespace" {
  description = "Namespace ArgoCD deploys the application into (created by sync option)"
  type        = string
  default     = "restaurant-api"
}

variable "argocd_chart_version" {
  description = <<-EOT
    argo-cd Helm chart version. Empty string = latest at install time;
    pin to the installed version afterwards for reproducible rebuilds
    (check with: helm list -n argocd).
  EOT
  type        = string
  default     = ""
}
