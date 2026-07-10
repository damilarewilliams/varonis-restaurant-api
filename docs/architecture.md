# Production Architecture

## Overview

A production-grade restaurant recommendation API deployed to Amazon EKS via GitOps.
Application delivery and infrastructure provisioning are both fully automated;
humans approve, pipelines execute.

## End-to-end flow

```
GitHub (source of truth)
  └─> GitHub Actions CI/CD
        ├─ App CI: lint → static analysis → (Could use pre-commit hooks as well)
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

- **Everything as code.** All AWS resources are provisioned by Terraform modules -
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

---

## AWS network architecture

A single VPC per environment, spanning **three Availability Zones** for
control-plane and node-group high availability.

```
VPC 10.0.0.0/16 (dev)
├── AZ a                      AZ b                      AZ c
│   ├── public  10.0.0.0/20   public  10.0.16.0/20     public  10.0.32.0/20
│   │     · ALB / NLB (Ingress)      · NAT gateway per AZ
│   └── private 10.0.64.0/20  private 10.0.80.0/20     private 10.0.96.0/20
│         · EKS worker nodes (no public IPs)
│         · runner pods, ArgoCD, application pods
├── Internet Gateway (public subnets only)
└── VPC endpoints: ECR (api+dkr), S3 (gateway), CloudWatch Logs, DynamoDB (gateway)
```

Design decisions:

- **Nodes only in private subnets.** Worker nodes never receive public IPs;
  inbound traffic reaches pods exclusively through a load balancer in the
  public subnets, created by the Ingress controller.
- **One NAT gateway per AZ** for AZ-fault isolation of outbound traffic. (A
  single shared NAT is the cheaper dev-mode alternative - the Terraform
  networking module exposes this as a variable so dev can run cheap while the
  architecture stays production-shaped.)
- **VPC endpoints** for ECR, S3, CloudWatch Logs, and DynamoDB keep
  image pulls, log shipping, and data traffic on the AWS backbone instead of
  traversing NAT - lower cost, smaller attack surface.
- **EKS API endpoint**: public with CIDR allowlist in dev (lets GitHub-hosted
  runners run Terraform without VPN infrastructure); private-only is the
  hardened option and is a module variable, not a redesign.

## EKS architecture

```
EKS cluster (managed control plane, 3 AZs)
├── Managed node group (private subnets, autoscaling min/max)
├── Add-ons: VPC CNI · CoreDNS · kube-proxy · EBS CSI driver
├── OIDC provider  ──►  IRSA (IAM Roles for Service Accounts)
└── Namespaces
    ├── argocd           ← ArgoCD (installed by Terraform)
    ├── arc-runners      ← self-hosted CD runners (installed by Terraform)
    ├── ingress          ← AWS Load Balancer Controller
    └── restaurant-api   ← the application (deployed by ArgoCD)
```

- **Managed node groups** over self-managed: AWS handles AMI patching and
  drain-on-upgrade; nothing about this workload needs custom nodes.
- **IRSA everywhere.** Pods get AWS permissions through IAM roles bound to
  Kubernetes service accounts via the cluster OIDC provider. The API pod's role
  allows DynamoDB read on one table; the runner pods get only what CD jobs
  need. No node-level instance-profile permissions, no static keys in-cluster.
- **Namespace isolation** separates platform components (argocd, arc-runners,
  ingress) from the workload; RBAC and NetworkPolicies are scoped per
  namespace (Issue #16).
- The application ships as Deployment + Service + Ingress + ConfigMap + Secret
  + HPA, with resource requests/limits, liveness/readiness probes, and rolling
  updates - packaged in the Helm chart (Issue #12).

## GitOps with ArgoCD

ArgoCD runs **inside the EKS cluster** (namespace `argocd`) and operates on a
**pull model**: the cluster continuously pulls its desired state from Git
rather than CI pushing manifests with `kubectl`. This means GitHub Actions
never holds cluster-admin credentials - the deployment trust boundary stays
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
revert`** of the values bump - the cluster converges back automatically.

**Bootstrap.** ArgoCD itself is installed by Terraform (Helm provider) so the
"everything provisioned by Terraform" requirement holds - see ADR-004. The
`Application` CR is applied the same way, so a fresh environment comes up
end-to-end from `terraform apply` with zero manual `kubectl` steps.

## CI/CD pipeline architecture

```
PR opened ──► CI: checkout → python setup → deps → lint → static analysis → unit tests
              (+ terraform fmt/validate on infra paths)          [GitHub-hosted]

merge to main
  ├─ infra changed? ──► terraform init → plan → upload plan artifact
  │                     → plan summary on run page
  │                     → ⏸ GitHub Environment "dev-infra": required reviewer
  │                     → apply THE UPLOADED PLAN artifact → verify outputs
  │                                                              [GitHub-hosted]
  ├─ app changed?  ──► docker build → Trivy scan (fail on HIGH/CRITICAL)
  │                     → push to registry → update values.yaml image.tag
  │                     → commit [skip ci] → push                [GitHub-hosted]
  │                          └──► ArgoCD sync
  └─ CD verify     ──► trigger/wait ArgoCD sync → kubectl rollout status
                        → /health + /ready checks → smoke tests  [ARC, in-cluster]
```

**Plan/apply separation.** The plan job writes `tfplan` as a workflow artifact
and posts a human-readable summary. The apply job targets a **GitHub
Environment** with a **required reviewer**: GitHub pauses the job until an
authorized person approves, and the job then applies the *downloaded artifact*
(`terraform apply tfplan`) - the exact plan that was reviewed, not a fresh
plan that could differ. Details in Issue #15.

**Loop prevention.** The values-bump commit is made with `[skip ci]` and the
workflow has path filters, so CI does not re-trigger itself.

### CI/CD runner topology

Pipeline jobs are split across two runner types (see ADR-005):

| Stage | Runner | Why |
|-------|--------|-----|
| CI (lint, tests, static analysis) | GitHub-hosted | No AWS access needed; zero maintenance |
| Terraform (fmt/validate/plan/apply) | GitHub-hosted | Must work before the cluster exists (bootstrap) and when it is broken (recovery) |
| Docker build, Trivy scan, image push | GitHub-hosted | Talks to the registry via OIDC; no cluster access needed |
| CD (ArgoCD sync trigger, rollout wait, health/readiness checks, smoke tests) | **Self-hosted: ARC on EKS** | Needs network access to the in-cluster ArgoCD API and Services; runs as ephemeral pods with IRSA |

**ARC (actions-runner-controller)** is installed into the cluster by Terraform's
Helm provider (same pattern as ArgoCD), in its own `arc-runners` namespace.
Runners are **ephemeral** - a fresh pod per job, scaled from zero - and
authenticate to AWS via **IRSA**, not static credentials. Because only CD jobs
target ARC, there is no circular dependency: Terraform never needs a runner
that lives on the cluster it is creating, and CD jobs are only meaningful when
the cluster is healthy anyway.

## Security architecture

Defense in depth, layer by layer:

| Layer | Control |
|-------|---------|
| Source | Branch protection, CODEOWNERS review, no secrets in Git (`.gitignore` + GitHub secret scanning) |
| CI → AWS | **GitHub OIDC federation** - short-lived role assumption, zero long-lived AWS keys in GitHub Secrets |
| Supply chain | Trivy scans every image; pipeline fails on HIGH/CRITICAL CVEs before push |
| Registry | Private ECR, scan-on-push enabled, immutable tags |
| IAM | Least privilege per principal: CI role (plan/apply scoped), app pod role (DynamoDB read on one table), runner role (CD verification only) - all via IRSA where in-cluster |
| Network | Private nodes, security groups, NetworkPolicies between namespaces, VPC endpoints |
| Data | DynamoDB encrypted at rest (KMS CMK), CloudWatch log groups KMS-encrypted, EBS volumes encrypted |
| Runtime | Non-root container, read-only root filesystem, no privilege escalation, resource limits |
| Secrets | GitHub Secrets for pipeline; Kubernetes Secrets for runtime config; no credentials in code or images |

The KMS module provides customer-managed keys with rotation enabled; every
encrypted-at-rest service (DynamoDB, CloudWatch Logs, EBS) references them.
Full control-by-control rationale lands in `docs/security.md` (Issue #16).

## Logging & observability architecture

Logs are treated as **sensitive data**.

```
FastAPI app
  └─ structured JSON logs (one event per line)
     · request id, method, path, status, latency
     · sensitive fields masked in-process (tokens, auth headers, PII)
  └─ stdout ──► container runtime
                 └─► Fluent Bit DaemonSet (node-level collector)
                       └─► CloudWatch Logs
                             · KMS-encrypted log group
                             · retention policy (no unbounded storage)
                             · IAM: writers can write, not read;
                               readers scoped to the log group
```

- **Masking happens in the application**, before a log line ever leaves the
  process - collectors and storage never see raw secrets. Masking at the
  collector would leave a window where secrets exist in plaintext.
- **Structured JSON** makes logs queryable in CloudWatch Logs Insights
  (`filter status >= 500 | stats count() by path`).
- **Least-privilege log access:** the shipper role can only `PutLogEvents` to
  the app's log group; human read access is a separate, scoped policy.
- Health surface: `/health` (liveness - process is up) and `/ready`
  (readiness - dependencies reachable), consumed by Kubernetes probes and CD
  smoke tests (Issue #17).

---

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
troubleshooting - see the `docs/` directory and `docs/decision-log.md`.
