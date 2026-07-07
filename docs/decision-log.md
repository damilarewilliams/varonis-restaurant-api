# Decision Log

Running record of non-obvious technical decisions. Newest entries at the bottom.
Format: context → options considered → decision → consequences.

---

## ADR-001: Single repository (monorepo) for app, infrastructure, and deployment config

**Date:** 2026-07-07 · **Status:** Accepted

**Context.** The system spans application code (FastAPI), infrastructure
(Terraform), packaging (Helm), and pipelines (GitHub Actions). They could live
in one repository or be split (e.g., separate infra repo, separate GitOps
config repo).

**Options.**
1. Monorepo — everything in one place.
2. Polyrepo — `app`, `infra`, and `gitops-config` repositories.

**Decision.** Monorepo. For a single-service system with one team, a monorepo
gives atomic changes (an issue that touches app + chart + pipeline merges as one
PR), a single review surface, and a single decision log. Polyrepo separation of
GitOps config is valuable at scale (many services, separate ownership) but is
overhead here. ArgoCD supports pointing at a path within a repo, so GitOps does
not require a dedicated config repo.

**Consequences.** CI must use path filters so app-only changes don't trigger
Terraform stages and vice versa. The CI-driven `values.yaml` bump commits back
to the same repository, which requires a loop-prevention guard (`[skip ci]` /
path filters) — addressed in the CI/CD issue.

---

## ADR-002: Feature-branch workflow with squash merges, no direct commits to main

**Date:** 2026-07-07 · **Status:** Accepted

**Context.** `main` is the source of truth for both infrastructure (Terraform
apply) and deployments (ArgoCD watches it). A broken `main` can converge broken
state into the cluster.

**Options.**
1. Trunk-based with direct pushes — fastest, no protection.
2. Feature branches + PR review + branch protection.
3. GitFlow (develop/release branches) — heavyweight for a single environment.

**Decision.** Feature branches with PRs into a protected `main`, squash merged.
Every change is reviewed and CI-validated before it can affect real
infrastructure. Squash merging keeps history one-commit-per-issue, which makes
rollbacks (git revert = GitOps rollback) clean. GitFlow adds release branching
we don't need with a single `dev` environment and continuous delivery.

**Consequences.** Branch protection on `main` must be configured in GitHub
(require PR, require status checks, require code owner review). CI's automated
values-bump commit needs an exemption strategy, decided in the CI/CD issue.

---

## ADR-003: Conventional Commits for commit messages

**Date:** 2026-07-07 · **Status:** Accepted

**Context.** Commit history doubles as an audit trail for infrastructure
changes.

**Decision.** Adopt Conventional Commits (`type(scope): summary`). Machine-
parseable history enables changelog generation and makes `git log` scannable
during incident review. Enforced socially via CONTRIBUTING.md and PR review
rather than a commit-lint hook, to keep tooling minimal.

**Consequences.** Reviewers check commit format as part of PR review.

---

## ADR-004: ArgoCD pull-based GitOps, bootstrapped by Terraform

**Date:** 2026-07-07 · **Status:** Accepted

**Context.** Deployments must reach EKS automatically after CI produces an
image. Something has to apply Kubernetes manifests, and something has to
install that something.

**Options.**
1. **Push-based CD** — GitHub Actions runs `helm upgrade` against the cluster.
   Simple, but CI must hold long-lived cluster credentials in GitHub, there is
   no drift detection, and cluster state silently diverges from Git.
2. **Pull-based GitOps (ArgoCD)** — controller in the cluster reconciles
   against Git. No cluster credentials leave AWS; drift is detected and
   self-healed; rollback is `git revert`.
3. Flux — equivalent pull model; ArgoCD chosen for its UI (useful for
   demonstrating sync state) and because the assignment names it.

For bootstrap: manual `kubectl apply` of ArgoCD manifests vs Terraform
`helm_release`.

**Decision.** ArgoCD, installed via Terraform's Helm provider, with the
`Application` CR also managed by Terraform. Sync policy: automated + prune +
self-heal. CI's only deployment action is committing a new image tag to
`values.yaml` — Git remains the single source of truth and the audit trail.

**Consequences.** Two actors manage cluster resources (Terraform installs
ArgoCD; ArgoCD manages the app) — the boundary is strict: Terraform never
touches the `restaurant-api` namespace contents. ArgoCD polling adds up to ~3
minutes of deploy latency unless a GitHub webhook is configured. The CI
values-bump commit to `main` must bypass/satisfy branch protection (bot
exception or PR automerge) — resolved in the CI/CD issue.

---

## ADR-005: Self-hosted runners via actions-runner-controller (ARC) on EKS, scoped to CD jobs only

**Date:** 2026-07-07 · **Status:** Accepted

**Context.** CD-stage jobs (trigger/verify ArgoCD sync, wait for rollout,
health and readiness validation, smoke tests) need network reach into the
cluster — the ArgoCD API and Kubernetes Services are not exposed publicly.
GitHub-hosted runners cannot reach them.

**Options.**
1. **GitHub-hosted runners + public exposure** — expose ArgoCD/endpoints
   publicly with IP allowlists. Weakens the security posture for CI
   convenience.
2. **EC2 self-hosted runner in the VPC** — cluster-independent (can also run
   Terraform against a private endpoint, and recover a broken cluster), but a
   long-lived VM to patch, a static instance profile, and state shared
   between jobs.
3. **ARC on EKS for all post-CI stages** — circular dependency: the first
   `terraform apply` would need a runner on the cluster it is creating.
4. **ARC on EKS, CD jobs only** — CI, Terraform, and image build/push stay on
   GitHub-hosted runners; only cluster-facing CD jobs run on ARC.

**Decision.** Option 4. Ephemeral runner pods (fresh pod per job, scale from
zero) eliminate inter-job state leakage; IRSA replaces static credentials;
there is no VM to maintain. The dependency graph stays acyclic because
Terraform never requires a runner hosted on the cluster it manages — ARC is
installed by Terraform after cluster creation, alongside ArgoCD. CD jobs
depending on a healthy cluster is acceptable: deploying to an unhealthy
cluster is meaningless.

**Consequences.** A new Terraform concern: ARC Helm release + `arc-runners`
namespace + IRSA role, plus a GitHub App (or PAT) credential for runner
registration stored in GitHub Secrets / a Kubernetes Secret. CD workflow jobs
must declare `runs-on` with the ARC runner group label. Runner pods need
resource requests/limits and should be restricted (non-root, no privileged
containers). If the cluster is down, CD jobs queue until ARC returns —
Terraform and CI are unaffected.
