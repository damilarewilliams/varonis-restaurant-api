# Module: argocd
# Installs ArgoCD (the GitOps reconciler, ADR-004) AND declares the
# Application that points it at the app chart — one helm_release, so a
# fresh environment converges from `terraform apply` to a deployed app
# with zero manual kubectl steps.

terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version != "" ? var.argocd_chart_version : null

  # Fail loudly and atomically: a half-installed GitOps controller is
  # worse than none.
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      # dev-appropriate ArgoCD posture: no public exposure — the UI is
      # reached via `kubectl port-forward svc/argocd-server -n argocd 8080:443`.
      server = {
        service = {
          type = "ClusterIP"
        }
      }

      configs = {
        params = {
          # TLS terminates at the port-forward/ingress layer in this
          # setup; ArgoCD serves plain HTTP inside the cluster.
          "server.insecure" = true
        }
      }

      # The Application CR ships WITH the ArgoCD release (extraObjects):
      # avoids a second Terraform apply step and the kubernetes_manifest
      # plan-time-cluster-access problem.
      extraObjects = [
        {
          apiVersion = "argoproj.io/v1alpha1"
          kind       = "Application"
          metadata = {
            name      = "${var.project}-${var.environment}"
            namespace = "argocd"
          }
          spec = {
            project = "default"

            source = {
              repoURL        = var.repo_url
              targetRevision = var.target_revision
              path           = var.chart_path
            }

            destination = {
              # in-cluster: ArgoCD manages the cluster it runs on (ADR-004)
              server    = "https://kubernetes.default.svc"
              namespace = var.app_namespace
            }

            syncPolicy = {
              automated = {
                # prune: resources removed from Git are removed from the
                # cluster. selfHeal: manual cluster edits are reverted —
                # Git is the ONLY write path to the app namespace.
                prune    = true
                selfHeal = true
              }
              syncOptions = [
                # The app chart deliberately doesn't template a Namespace;
                # its lifecycle belongs to the platform (chart README).
                "CreateNamespace=true",
              ]
            }
          }
        },
      ]
    }),
  ]
}
