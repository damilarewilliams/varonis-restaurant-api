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
1. Monorepo - everything in one place.
2. Polyrepo - `app`, `infra`, and `gitops-config` repositories.

**Decision.** Monorepo. For a single-service system with one team, a monorepo
gives atomic changes (an issue that touches app + chart + pipeline merges as one
PR), a single review surface, and a single decision log. Polyrepo separation of
GitOps config is valuable at scale (many services, separate ownership) but is
overhead here. ArgoCD supports pointing at a path within a repo, so GitOps does
not require a dedicated config repo.

**Consequences.** CI must use path filters so app-only changes don't trigger
Terraform stages and vice versa. The CI-driven `values.yaml` bump commits back
to the same repository, which requires a loop-prevention guard (`[skip ci]` /
path filters) - addressed in the CI/CD issue.

---

## ADR-002: Feature-branch workflow with squash merges, no direct commits to main

**Date:** 2026-07-07 · **Status:** Accepted

**Context.** `main` is the source of truth for both infrastructure (Terraform
apply) and deployments (ArgoCD watches it). A broken `main` can converge broken
state into the cluster.

**Options.**
1. Trunk-based with direct pushes - fastest, no protection.
2. Feature branches + PR review + branch protection.
3. GitFlow (develop/release branches) - heavyweight for a single environment.

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
1. **Push-based CD** - GitHub Actions runs `helm upgrade` against the cluster.
   Simple, but CI must hold long-lived cluster credentials in GitHub, there is
   no drift detection, and cluster state silently diverges from Git.
2. **Pull-based GitOps (ArgoCD)** - controller in the cluster reconciles
   against Git. No cluster credentials leave AWS; drift is detected and
   self-healed; rollback is `git revert`.
3. Flux - equivalent pull model; ArgoCD chosen for its UI (useful for
   demonstrating sync state) and because the assignment names it.

For bootstrap: manual `kubectl apply` of ArgoCD manifests vs Terraform
`helm_release`.

**Decision.** ArgoCD, installed via Terraform's Helm provider, with the
`Application` CR also managed by Terraform. Sync policy: automated + prune +
self-heal. CI's only deployment action is committing a new image tag to
`values.yaml` - Git remains the single source of truth and the audit trail.

**Consequences.** Two actors manage cluster resources (Terraform installs
ArgoCD; ArgoCD manages the app) - the boundary is strict: Terraform never
touches the `restaurant-api` namespace contents. ArgoCD polling adds up to ~3
minutes of deploy latency unless a GitHub webhook is configured. The CI
values-bump commit to `main` must bypass/satisfy branch protection (bot
exception or PR automerge) - resolved in the CI/CD issue.

---

## ADR-005: Self-hosted runners via actions-runner-controller (ARC) on EKS, scoped to CD jobs only

**Date:** 2026-07-07 · **Status:** Accepted

**Context.** CD-stage jobs (trigger/verify ArgoCD sync, wait for rollout,
health and readiness validation, smoke tests) need network reach into the
cluster - the ArgoCD API and Kubernetes Services are not exposed publicly.
GitHub-hosted runners cannot reach them.

**Options.**
1. **GitHub-hosted runners + public exposure** - expose ArgoCD/endpoints
   publicly with IP allowlists. Weakens the security posture for CI
   convenience.
2. **EC2 self-hosted runner in the VPC** - cluster-independent (can also run
   Terraform against a private endpoint, and recover a broken cluster), but a
   long-lived VM to patch, a static instance profile, and state shared
   between jobs.
3. **ARC on EKS for all post-CI stages** - circular dependency: the first
   `terraform apply` would need a runner on the cluster it is creating.
4. **ARC on EKS, CD jobs only** - CI, Terraform, and image build/push stay on
   GitHub-hosted runners; only cluster-facing CD jobs run on ARC.

**Decision.** Option 4. Ephemeral runner pods (fresh pod per job, scale from
zero) eliminate inter-job state leakage; IRSA replaces static credentials;
there is no VM to maintain. The dependency graph stays acyclic because
Terraform never requires a runner hosted on the cluster it manages - ARC is
installed by Terraform after cluster creation, alongside ArgoCD. CD jobs
depending on a healthy cluster is acceptable: deploying to an unhealthy
cluster is meaningless.

**Consequences.** A new Terraform concern: ARC Helm release + `arc-runners`
namespace + IRSA role, plus a GitHub App (or PAT) credential for runner
registration stored in GitHub Secrets / a Kubernetes Secret. CD workflow jobs
must declare `runs-on` with the ARC runner group label. Runner pods need
resource requests/limits and should be restricted (non-root, no privileged
containers). If the cluster is down, CD jobs queue until ARC returns -
Terraform and CI are unaffected.

---

## ADR-006: Terraform remote state in S3 with native lockfile locking

**Date:** 2026-07-08 · **Status:** Accepted

**Context.** Terraform state must be shared between engineers and CI, must
survive laptops, and must be protected against concurrent applies. State can
contain sensitive values, so it needs encryption and access control.

**Options.**
1. **Local state committed to Git** - never: secrets in Git, merge conflicts,
   no locking.
2. **S3 + DynamoDB lock table** - the long-standing standard; requires
   provisioning and paying for a lock table whose only job is locking.
3. **S3 with native lockfile (`use_lockfile`)** - Terraform >= 1.10 locks via
   a conditional-write lock object in the same bucket. Same concurrency
   protection, one less resource.
4. Terraform Cloud/HCP - external dependency and account beyond the
   assignment's AWS scope.

**Decision.** Option 3. The state bucket is versioned (state history =
rollback), KMS-encrypted (state is sensitive), and public-access-blocked.
`required_version >= 1.10.0` is enforced in `versions.tf`.

**Bootstrap exception.** The state bucket cannot be managed by the state it
stores. It is the single resource created outside Terraform, via four
documented CLI commands in `backend.tf`. Alternatives (a separate bootstrap
Terraform config with local state) add moving parts without adding safety at
this scale.

**Consequences.** Anyone running Terraform needs >= 1.10 locally. The AWS
provider is constrained to a bounded range with the exact version pinned by
the committed `.terraform.lock.hcl`. Environments/modules split (see
`terraform/README.md`): modules are environment-agnostic building blocks;
adding staging/prod is a new composition root, not copied resources.

---

## ADR-007: Amazon ECR over Docker Hub for the container registry

**Date:** 2026-07-08 · **Status:** Accepted

**Context.** The original project brief said "push image to docker-hub";
the infrastructure plan (Issue #8) provisions ECR. The discrepancy needed a
decision.

**Options.**
1. **Docker Hub** - requires a stored username/token secret in GitHub and in
   the cluster (imagePullSecrets); free tier has pull rate limits that
   throttle node image pulls; traffic traverses the public internet.
2. **Amazon ECR** - IAM-native: CI pushes via its OIDC-assumed role, nodes
   pull via their instance role, zero registry credentials exist anywhere;
   no rate limits; reachable through the VPC interface endpoints already
   provisioned (pulls never leave the AWS backbone); scan-on-push adds a
   second scanning layer behind Trivy.

**Decision.** ECR. Every property we care about - no stored credentials,
private network path, registry-side scanning - is native. Immutable tags
are enabled so a values.yaml tag always references the same image bytes,
which is what makes GitOps rollback trustworthy. A lifecycle policy bounds
storage (untagged expire at 7 days, last 20 tagged retained).

**Consequences.** The brief's "docker-hub" step becomes "push to ECR" in
the pipeline (Issue #14). Image URLs are account-scoped
(<account>.dkr.ecr.<region>.amazonaws.com/...), injected into Helm values
by CI rather than hardcoded.

---

## ADR-008: GitHub OIDC federation with per-job CI roles; no static AWS keys

**Date:** 2026-07-08 · **Status:** Accepted

**Context.** CI needs AWS access for two very different jobs: pushing
images (narrow) and running Terraform (broad). The traditional approach -
an IAM user's access key stored in GitHub Secrets - is a long-lived
credential that leaks, never rotates itself, and grants whoever holds it
everything CI can do.

**Options.**
1. **IAM user access keys in GitHub Secrets** - long-lived, manually
   rotated, one blast radius for all pipeline jobs.
2. **GitHub OIDC federation** - GitHub Actions presents a short-lived
   signed job token; AWS validates it against trust conditions and issues
   temporary credentials. Nothing stored, nothing to rotate, and the trust
   policy can distinguish *which* workflow/branch/environment is asking.

**Decision.** OIDC federation with two separately-scoped roles:
`gha-delivery` (ECR push only, assumable only from `refs/heads/main`) and
`gha-terraform` (infra provisioning, assumable only from jobs in the
protected `dev-infra` GitHub Environment - the same human-approval gate as
the apply step). The terraform role is PowerUserAccess plus IAM re-granted
strictly on `<project>-<env>-*` roles, so CI manages this stack's
identities and nothing else in the account.

**Consequences.** GitHub stores role *ARNs* (not secrets) as Actions
variables. A compromised PR or fork workflow can assume neither role (sub
conditions fail). The IAM-by-prefix bound means any future role this stack
creates must follow the `<project>-<env>-` naming convention - enforced by
the modules' `name_prefix` locals.

---

## ADR-009: Plan approval via GitHub Environments; ruleset bypass for the GitOps bot

**Date:** 2026-07-10 · **Status:** Accepted

**Context.** Terraform apply must be human-gated on the exact reviewed
plan (assignment requirement). Separately, the delivery pipeline commits
the values.yaml bump directly to a protected `main` - something branch
protection normally forbids.

**Options for the apply gate.**
1. **GitHub Environments with required reviewers** - native, zero extra
   infrastructure, audit trail on the run, and (critically) the OIDC
   token carrying the `environment:dev-infra` claim is not issued until
   approval, so the gate controls *credentials*, not just job order.
2. Atlantis - PR-comment-driven plan/apply; a service to host and secure.
3. Terraform Cloud runs - external platform beyond the AWS scope.
4. `workflow_dispatch` manual apply - human-triggered but reviews
   intention, not a concrete plan artifact.

**Decision.** Option 1, with two environments: `dev-infra-plan`
(unprotected - computing a diff needs no human) and `dev-infra`
(required reviewers - mutating infrastructure does). The apply job runs
`terraform apply tfplan` on the downloaded artifact; Terraform's own
state-consistency check guarantees the reviewed plan is what executes.
Full explanation: docs/plan-approval.md.

**Options for the bot commit vs branch protection.**
1. **Ruleset bypass for `github-actions[bot]`** - narrow, attributed,
   audited; the bot's behavior is itself defined by PR-reviewed workflow
   code.
2. Bot opens auto-merged PRs - latency and noise, no added control.
3. Deploy PAT with bypass - a long-lived secret where none is needed.

**Decision.** Option 1.

**Consequences.** Approval quality depends on reviewers actually reading
the plan summary - the workflow renders it on the run page to make that
easy. On a personal repository the sole maintainer approves their own
applies; in an organization the reviewer set would exclude the author.
The bot bypass means a compromised workflow with `contents: write` could
push to main - mitigated by CODEOWNERS review on all workflow changes.

---

## ADR-010: Bootstrap trust anchors - what must exist before the pipeline can

**Date:** 2026-07-10 · **Status:** Accepted

**Context.** "Everything is provisioned by the pipeline" is circular at
t=0: the pipeline needs AWS credentials (an OIDC provider + IAM role that
something must create), Terraform needs a state backend (a bucket that
cannot manage itself), and the CI role needs Kubernetes access (an EKS
access entry that only an existing cluster admin can grant). Discovered
concretely when CI's kubernetes/helm providers failed `Unauthorized`:
the cluster creator gets an admin access entry automatically; a CI role
does not.

**Decision.** Accept exactly three bootstrap actions performed once with
operator credentials, each documented where it lives: (1) the state
bucket (CLI commands in backend.tf), (2) the first `terraform apply`,
which creates the OIDC provider, CI roles, and the CI role's cluster
access entry - from then on the pipeline is self-hosting, (3) the ARC
PAT placed in GitHub Secrets. Everything else, including later changes
to the trust anchors themselves, flows through the pipeline.

**Consequences.** The bootstrap is a documented, finite list rather than
an implicit pile of console actions; a fresh account reaches
pipeline-self-sufficiency in one local apply. The trade-off is that the
first apply runs ungated - reviewed only by the operator running it.
