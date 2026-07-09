# Module: arc
# actions-runner-controller (ADR-005): ephemeral self-hosted runners as
# pods, CD jobs only. Scale-from-zero, fresh pod per job, IRSA auth.

terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# Runner namespace + service account are OURS (not chart-created) so the
# IRSA annotation matches the trust policy in the iam module exactly:
# system:serviceaccount:arc-runners:arc-runner
resource "kubernetes_namespace" "runners" {
  metadata {
    name = "arc-runners"
  }
}

resource "kubernetes_service_account" "runner" {
  metadata {
    name      = "arc-runner"
    namespace = kubernetes_namespace.runners.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = var.runner_role_arn
    }
  }
}

# The controller: watches for queued workflow jobs, spins up runner pods.
resource "helm_release" "controller" {
  name             = "arc-controller"
  namespace        = "arc-systems"
  create_namespace = true

  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set-controller"

  atomic  = true
  timeout = 600
}

# The scale set: registers with the repo; its NAME is the runs-on label.
resource "helm_release" "runners" {
  name      = var.runner_scale_set_name
  namespace = kubernetes_namespace.runners.metadata[0].name

  repository = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart      = "gha-runner-scale-set"

  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      githubConfigUrl = var.github_repository_url
      githubConfigSecret = {
        github_token = var.github_token
      }

      runnerScaleSetName = var.runner_scale_set_name
      minRunners         = 0 # scale from zero: no idle cost
      maxRunners         = var.max_runners

      # Custom pod template: our IRSA service account. When template.spec
      # is set, the runner container must be declared explicitly.
      template = {
        spec = {
          serviceAccountName = kubernetes_service_account.runner.metadata[0].name
          containers = [
            {
              name    = "runner"
              image   = "ghcr.io/actions/actions-runner:latest"
              command = ["/home/runner/run.sh"]
            },
          ]
        }
      }
    }),
  ]

  depends_on = [helm_release.controller]
}
