output "namespace" {
  description = "Namespace ArgoCD is installed in"
  value       = helm_release.argocd.namespace
}

output "application_name" {
  description = "ArgoCD Application name (used by CD verification: argocd app wait <name>)"
  value       = "${var.project}-${var.environment}"
}
