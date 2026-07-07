# Architecture

## Overview

A production-grade restaurant recommendation API deployed to Amazon EKS via GitOps.
Application delivery and infrastructure provisioning are both fully automated;
humans approve, pipelines execute.

## End-to-end flow

```
GitHub (source of truth)
  └─> GitHub Actions CI/CD
        ├─ App CI: lint → static analysis → unit tests
        ├─ Terraform: fmt → validate → plan → [manual approval] → apply → verify
        └─ Delivery: docker build → Trivy scan → push image
                      → bump Helm values.yaml → commit
                            └─> ArgoCD detects change → sync
                                  └─> Amazon EKS
                                        └─> Restaurant Recommendation API (FastAPI)
                                              ├─> Amazon DynamoDB (restaurant data)
                                              └─> Structured logs ──> CloudWatch (encrypted)
```

## Key properties

- **Everything as code.** All AWS resources are provisioned by Terraform modules —
  no console changes.
- **GitOps.** The cluster state converges to what is declared in Git. Deployments
  happen by committing a new image tag to `values.yaml`; ArgoCD reconciles.
- **Plan/apply separation.** Terraform apply requires human review of the exact
  uploaded plan artifact via a GitHub Environment with required reviewers.
- **DevSecOps.** Images are scanned with Trivy before push; IAM follows least
  privilege; storage and logs are encrypted; secrets live in GitHub Secrets and
  Kubernetes Secrets, never in code.
- **Observability.** The API emits structured JSON logs with sensitive-field
  masking, shipped to CloudWatch.

## GitOps with ArgoCD

ArgoCD runs **inside the EKS cluster** (namespace `argocd`) and operates on a
**pull model**: the cluster continuously pulls its desired state from Git
rather than CI pushing manifests with `kubectl`. This means GitHub Actions
never holds cluster-admin credentials — the deployment trust boundary stays
inside AWS.

```
                        ┌─────────────── EKS cluster ────────────────┐
GitHub repo             │  argocd namespace                          │
 └─ helm/restaurant-api │   ├─ repo-server ── clones repo, renders   │
     ├─ Chart.yaml   ◄──┼───┤               Helm chart to manifests  │
     ├─ values.yaml     │   ├─ application-controller ── compares    │
     └─ templates/      │   │   desired (Git) vs live (cluster),     │
                        │   │   syncs drift                          │
CI commits new          │   ├─ api-server / UI ── status, manual ops │
image tag to            │   └─ redis ── state cache                  │
values.yaml ────────►   │                                            │
                        │  restaurant-api namespace                  │
                        │   └─ Deployment / Service / Ingress / HPA  │
                        └────────────────────────────────────────────┘
```

**Core components.** The *repo-server* clones this repository and renders the
Helm chart into plain manifests. The *application-controller* is the
reconciliation loop: it diffs rendered (desired) state against live cluster
state and applies the difference. The *api-server* exposes the UI/CLI used by
the pipeline's "wait for rollout" step.

**The Application resource.** A single ArgoCD `Application` CR declares:
source = this repo, path `helm/restaurant-api`, targetRevision `main`;
destination = in-cluster, namespace `restaurant-api`; sync policy =
`automated` with `prune: true` (delete resources removed from Git) and
`selfHeal: true` (revert manual/out-of-band cluster changes).

**Deployment flow.** CI builds and scans the image, pushes it, then commits
the new image tag into `helm/restaurant-api/values.yaml` on `main`. ArgoCD
detects the commit (polling, ~3 min default; optionally a webhook for instant
sync), re-renders the chart, and rolls the Deployment. **Rollback = `git
revert`** of the values bump — the cluster converges back automatically.

**Bootstrap.** ArgoCD itself is installed by Terraform (Helm provider) so the
"everything provisioned by Terraform" requirement holds — see ADR-004. The
`Application` CR is applied the same way, so a fresh environment comes up
end-to-end from `terraform apply` with zero manual `kubectl` steps.

## CI/CD runner topology

Pipeline jobs are split across two runner types (see ADR-005):

| Stage | Runner | Why |
|-------|--------|-----|
| CI (lint, tests, static analysis) | GitHub-hosted | No AWS access needed; zero maintenance |
| Terraform (fmt/validate/plan/apply) | GitHub-hosted | Must work before the cluster exists (bootstrap) and when it is broken (recovery) |
| Docker build, Trivy scan, image push | GitHub-hosted | Talks to ECR via OIDC; no cluster access needed |
| CD (ArgoCD sync trigger, rollout wait, health/readiness checks, smoke tests) | **Self-hosted: ARC on EKS** | Needs network access to the in-cluster ArgoCD API and Services; runs as ephemeral pods with IRSA |

**ARC (actions-runner-controller)** is installed into the cluster by Terraform's
Helm provider (same pattern as ArgoCD), in its own `arc-runners` namespace.
Runners are **ephemeral** — a fresh pod per job, scaled from zero — and
authenticate to AWS via **IRSA**, not static credentials. Because only CD jobs
target ARC, there is no circular dependency: Terraform never needs a runner
that lives on the cluster it is creating, and CD jobs are only meaningful when
the cluster is healthy anyway.

## AWS components

| Component  | Purpose                                        |
|------------|------------------------------------------------|
| VPC        | Network isolation; private subnets for nodes   |
| EKS        | Managed Kubernetes control plane + node groups |
| ECR        | Private container registry                     |
| DynamoDB   | Restaurant data store (serverless, on-demand)  |
| IAM        | Least-privilege roles (IRSA for pods, OIDC for CI) |
| KMS        | Encryption keys for logs and storage           |
| CloudWatch | Log aggregation and metrics                    |

Details for each area live in their own documents as the system is built:
infrastructure, API, security, deployment, CI/CD, GitOps, monitoring,
troubleshooting — see the `docs/` directory and `docs/decision-log.md`.
