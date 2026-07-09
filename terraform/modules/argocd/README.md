# argocd module

Installs ArgoCD via the Helm provider and declares the Application that
points it at `helm/restaurant-api` — implementing ADR-004's pull-based
GitOps with Terraform-only bootstrap.

## Design decisions

- **One helm_release for controller + Application.** The Application CR
  rides in the chart's `extraObjects`, avoiding both a second apply step
  and `kubernetes_manifest`'s requirement for cluster access at plan time.
- **Automated sync with prune + selfHeal**: Git is the only write path to
  the app namespace; manual cluster edits revert automatically.
- **`CreateNamespace=true`** — the app chart deliberately does not manage
  its namespace (chart README).
- **ClusterIP + port-forward for the UI** in dev; no public ArgoCD
  exposure. `kubectl port-forward svc/argocd-server -n argocd 8080:443`,
  initial admin password:
  `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`
- **atomic install**: a half-installed GitOps controller rolls back.
- **Public repo = no repo credentials.** A private repo would add a
  repository secret (SSH key or GitHub App) — deliberately unnecessary here.

## Inputs

project/environment, repo_url, target_revision (`main`), chart_path
(`helm/restaurant-api`), app_namespace (`restaurant-api`),
argocd_chart_version (empty = latest; pin after first install).

## Outputs

namespace, application_name (used by CD verification jobs).
