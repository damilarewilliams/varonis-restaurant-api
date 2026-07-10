# Security

Every security control in the system, by layer, with its rationale and
where it lives. Consolidates decisions made across Issues #1–#16
(ADR references in [decision-log.md](decision-log.md)).

## Threat-model summary

The assets: the restaurant data (DynamoDB), the AWS account itself, the
deployment pipeline (which can change what runs), and the logs (treated
as sensitive). The interesting attackers: someone hijacking the public
repo's CI, someone compromising a pod, and someone abusing leaked
credentials - which is why the design's central property is that **no
long-lived credential exists anywhere in the system**.

## Control matrix

| Layer | Control | Why | Where |
|-------|---------|-----|-------|
| **Source** | Protected `main`: PRs + required CI checks + CODEOWNERS | No unreviewed change reaches the branch that drives infra and deploys | GitHub ruleset, `.github/CODEOWNERS` |
| | `.gitignore` blocks state/tfvars/keys; no credentials in code (`git grep` provably clean) | Secrets never enter history - history is forever | Issue #1 |
| | GitOps bot is the only ruleset bypass, single identity, audited | Pipeline must write values.yaml; scope is one bot, one file, reviewed workflow code | ADR-009 |
| **CI identity** | GitHub OIDC federation; zero AWS keys in GitHub | Short-lived tokens, nothing to leak or rotate | ADR-008, iam module |
| | Two CI roles: delivery (ECR push, `main` ref only) and terraform (protected-environment claim only) | A fork/PR workflow can assume neither; blast radii separated | iam module trust conditions |
| | Terraform role: PowerUser + IAM re-granted only on `<project>-<env>-*` roles | CI provisions everything yet cannot mint identities outside its fence | ADR-008 |
| | Apply gated by required reviewer; credentials issued only on approval | Human reviews the exact tfplan artifact before AWS mutates | ADR-009, docs/plan-approval.md |
| **Supply chain** | Trivy gate: HIGH/CRITICAL fails the pipeline before push | Vulnerable images never reach the registry | deploy.yml |
| | ECR scan-on-push + immutable tags + lifecycle policy | Continuous re-scanning; a tag can never change contents (trustworthy rollback) | ADR-007, ecr module |
| | Image: multi-stage, no build tools, pinned slim base | Minimal CVE surface for the scanners to find | Dockerfile |
| **Network** | Nodes/pods in private subnets, no public IPs; ingress only via ALB | Workloads unreachable from the internet by construction | networking module |
| | VPC endpoints for ECR/S3/Logs/DynamoDB | Service traffic never crosses the public internet | networking module |
| | **NetworkPolicy: default-deny, allow in-VPC→8000, egress DNS+443 only** | A compromised pod cannot reach neighbors or exfiltrate beyond HTTPS; enforcement enabled on the CNI (inert policy = worst control) | chart `networkpolicy.yaml`, eks module vpc-cni config |
| | EKS API: private access on; public restricted by CIDR variable | Dev convenience with a documented hardening path | eks module |
| **Workload identity** | IRSA per service account: API→one table read; runner→describe+view; shipper→write-only logs | Pod compromise yields only that pod's narrow role; node role carries no app permissions | iam, logging, eks modules |
| | EKS access entries (API mode), runner scoped to namespaced *View* | CD verifies, only ArgoCD mutates; auditable IAM-native access | iam module |
| **Runtime** | Non-root UID 10001, read-only rootfs, no privilege escalation, all capabilities dropped, RuntimeDefault seccomp | Container escape made maximally difficult; matches the image's own hardening | chart securityContext, Dockerfile |
| | Resource limits on every container | A misbehaving pod cannot starve the node | chart values |
| **Data** | DynamoDB: customer-managed KMS key, PITR, deletion protection (prod) | The data asset: auditable key usage, point-in-time recovery | dynamodb + kms modules |
| | Key-per-purpose CMKs (data / logs), rotation on | Separate blast radii; a leaked logs grant exposes no data | kms module |
| **Logs** | In-process masking → encrypted group → bounded retention → write-only shipper | Secrets never leave the process unmasked; storage encrypted; writers can't read | app/core/logging.py, logging module |
| | EKS control-plane audit logs, CMK-encrypted from first byte | API-server audit trail without the unencrypted-implicit-group trap | eks module |
| **GitOps** | Pull model: cluster credentials never leave AWS; selfHeal reverts manual edits | Git is the only write path to the app namespace | ADR-004, argocd module |

## Accepted trade-offs (known, documented, reversible)

1. **EKS public endpoint with `0.0.0.0/0`** in dev - flagged with a TODO;
   narrowing the CIDR or flipping `endpoint_public_access=false` is a
   variable change, not a redesign.
2. **Sole-maintainer approval** - on a personal repo the author approves
   their own applies; an organization would exclude the author.
3. **ArgoCD `server.insecure` behind ClusterIP** - TLS terminates at the
   port-forward; acceptable only because the server is never exposed.
4. **ARC registration PAT** - one real secret exists (GitHub secret /
   TF_VAR); a GitHub App is the lower-privilege upgrade.
5. **Bot ruleset bypass** - mitigated by CODEOWNERS review of all
   workflow changes (the code that drives the bot is itself gated).
6. **Public demo ELB (review window only)** - the Service runs as type
   LoadBalancer over plain HTTP so reviewers can reach the API without
   cluster access. Reverted to ClusterIP after review; the production
   path is the chart's Ingress once the AWS Load Balancer Controller is
   installed.

## Verifying the claims

```bash
# No hardcoded credentials anywhere in tracked code:
git grep -iE "aws_access_key|aws_secret|AKIA[0-9A-Z]{16}" -- ':!*.md' ; echo $?   # expect 1 (no matches)

# Rendered manifests carry the hardening (after helm template):
helm template t helm/restaurant-api --set image.repository=r --set image.tag=t \
  | grep -E "runAsNonRoot|readOnlyRootFilesystem|NetworkPolicy"

# Once live: pod-level proof
kubectl -n restaurant-api exec deploy/varonis-restaurant-api-dev -- whoami   # uid 10001, not root
kubectl -n restaurant-api get networkpolicy
```
