# Environment outputs — consumed by CI (infrastructure verification
# step) and by engineers. Populated as modules are enabled.
#
# Examples once modules land:
#   output "eks_cluster_name"  { value = module.eks.cluster_name }
#   output "ecr_repository_url" { value = module.ecr.repository_url }
