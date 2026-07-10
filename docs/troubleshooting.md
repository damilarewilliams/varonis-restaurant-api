# Troubleshooting

Symptom-first runbook. Commands assume kubeconfig via
`aws eks update-kubeconfig --name varonis-restaurant-api-dev`.

## Deploy merged but the app didn't update

```bash
kubectl -n argocd get application varonis-restaurant-api-dev   # SYNC/HEALTH status
kubectl -n restaurant-api get deploy varonis-restaurant-api-dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'      # which SHA is live?
```
ArgoCD polls (~3 min) — wait first. `OutOfSync` + errors: check the
values.yaml bump commit landed on main and the image tag exists in ECR
(`aws ecr describe-images --repository-name varonis-restaurant-api-dev`).
Trivy gate failure means no push and no bump — check the deploy run.

## Pods not Ready

```bash
kubectl -n restaurant-api describe pod -l app.kubernetes.io/name=restaurant-api
kubectl -n restaurant-api logs deploy/varonis-restaurant-api-dev
```
- `ImagePullBackOff`: tag/repo mismatch in values.yaml, or node role lost
  ECR read.
- Readiness failing, liveness fine → DynamoDB unreachable: wrong
  `APP_DYNAMODB_TABLE`, missing IRSA annotation on the ServiceAccount, or
  NetworkPolicy blocking 443 egress. Logs will show the boto3 error.
- CrashLoop: config error at startup — logs show it immediately.
- Probes fail with connection refused but app logs look fine →
  NetworkPolicy: is the CNI enforcing with the right `vpcCidr`?

## API returns empty recommendations in-cluster (works locally)

Table exists but is empty — run the seeder (deployment.md step 3). Or the
pod is on the memory backend: check `APP_REPOSITORY_BACKEND` in the
ConfigMap.

## Terraform plan/apply fails in CI

- `credentials could not be loaded`: environment name mismatch (job env
  vs IAM trust `dev-infra`/`dev-infra-plan`), or placeholder role ARN
  variables (validate: `gh variable list`).
- Backend errors: state bucket missing (bootstrap) or lock held — a
  crashed run leaves the S3 lockfile; `terraform force-unlock <id>` after
  confirming no apply is running.
- `AccessDenied` on an IAM call: the project-prefix fence working — the
  resource name doesn't start with `varonis-restaurant-api-dev-`.

## cd-verify queued forever

No ARC runner picked it up: ARC not applied (`TF_VAR_arc_github_token`
unset → module count 0), or scale set unregistered — check
`kubectl -n arc-systems logs deploy/arc-controller-gha-rs-controller`.

## No logs in CloudWatch

```bash
kubectl -n logging logs daemonset/fluent-bit | tail
```
`AccessDenied` → SA annotation/trust mismatch. `ResourceNotFound` → group
name mismatch (auto-create is deliberately off — fix the name, don't
enable it). No Fluent Bit pods → module not applied.

## ArgoCD UI access

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443   # https://localhost:8080
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d                 # user: admin
```

## Break-glass: pipeline is broken and infra must change

Terraform stages run on GitHub-hosted runners precisely so a broken
cluster can't block them (ADR-005). If GitHub itself is the problem: run
plan/apply locally with your admin identity against the same remote
state — then reconcile by merging the change afterward so Git matches
reality.
