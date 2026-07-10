# Module: argocd
# Installs ArgoCD (the GitOps reconciler, ADR-004) AND declares the
# Application that points it at the app chart — two helm_releases, so a
# fresh environment converges from `terraform apply` to a deployed app
# with zero manual kubectl steps.
#
# Why two releases and not extraObjects on one: the argo-cd chart
# installs the Application CRD, but Helm validates the WHOLE manifest
# against the API server before creating anything — an Application CR
# in extraObjects fails with "no matches for kind Application" on a
# fresh cluster. The upstream argocd-apps chart exists precisely for
# this: it renders Application CRs in a release that runs after the
# CRDs are registered.

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
    }),
  ]
}

# The Application CR ships in a second release (see module header for
# why it cannot ride along as extraObjects). depends_on guarantees the
# CRDs from the argo-cd release are registered before this validates.
resource "helm_release" "application" {
  name      = "argocd-apps"
  namespace = "argocd"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version != "" ? var.argocd_apps_chart_version : null

  atomic  = true
  timeout = 300

  values = [
    yamlencode({
      applications = {
        "${var.project}-${var.environment}" = {
          namespace = "argocd"
          project   = "default"

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
      }
    }),
  ]

  depends_on = [helm_release.argocd]
}
