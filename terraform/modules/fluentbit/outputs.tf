output "namespace" {
  description = "Namespace the shipper runs in"
  value       = kubernetes_namespace.this.metadata[0].name
}
