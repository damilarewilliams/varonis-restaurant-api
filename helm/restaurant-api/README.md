# restaurant-api Helm chart

Packages the API for GitOps deployment: ArgoCD watches this directory on
`main` and reconciles the cluster to it (ADR-004). CI updates
`values.yaml` `image.tag` on every delivery — that commit IS the deploy.

## Objects rendered

Deployment (rolling update, probes, resources, hardening) · Service
(ClusterIP) · Ingress (ALB) · ServiceAccount (IRSA annotation) ·
ConfigMap (non-sensitive env) · Secret (optional, values injected
out-of-band) · HorizontalPodAutoscaler (CPU).

**Namespace** is deliberately not templated: ArgoCD creates it with the
`CreateNamespace=true` sync option (Issue #13). The namespace's lifecycle
belongs to the platform, not to the app chart.

## Key decisions

- **Zero-downtime rollout**: `maxSurge: 1, maxUnavailable: 0` — a new pod
  must pass readiness before any old pod is removed.
- **Config checksum annotation**: ConfigMap changes roll the pods
  automatically; without it, config edits silently apply on the *next*
  unrelated deploy.
- **Liveness ≠ readiness**: liveness (`/health/live`) checks only the
  process — dependency outages must not cause restart storms; readiness
  (`/health/ready`) gates traffic on dependency health.
- **Security context matches the image**: runAsNonRoot UID 10001,
  read-only root filesystem, no privilege escalation, all capabilities
  dropped, RuntimeDefault seccomp.
- **HPA targets CPU % of requests** with sane bounds (2–5); when HPA is
  enabled the Deployment omits `replicas` so the two never fight.
- **No secrets in Git**: `secret.create` defaults to false; real values
  arrive via `kubectl create secret` or an external-secrets operator.

## Local rendering

```bash
helm lint helm/restaurant-api
helm template test helm/restaurant-api \
  --set image.repository=example.com/repo --set image.tag=abc123 | less
```
