# Varonis Restaurant Recommendation API

Production-grade, cloud-native restaurant recommendation system built to
demonstrate DevOps and Platform Engineering practice: Infrastructure as Code,
GitOps, CI/CD, Kubernetes, and DevSecOps.

## Stack

**App:** Python, FastAPI · **Infra:** Terraform (reusable modules), AWS (VPC,
EKS, ECR, DynamoDB, IAM, KMS, CloudWatch) · **Delivery:** Docker, Helm, ArgoCD,
GitHub Actions, Trivy · **Practices:** GitOps, least-privilege IAM, encrypted
storage, structured logging with sensitive-field masking.

## Architecture

```
GitHub → GitHub Actions → Terraform (plan → approval → apply)
       → Docker build → Trivy scan → push image
       → bump Helm values.yaml → commit → ArgoCD sync → EKS
                                                          └─ FastAPI ─ DynamoDB
                                                          └─ logs ─ CloudWatch
```

Full diagram and rationale: [docs/architecture.md](docs/architecture.md).

## Repository layout

```
.
├── app/          # FastAPI application source
├── terraform/    # IaC: environments/ + reusable modules/
├── helm/         # Helm chart for the API
├── scripts/      # Operational and CI helper scripts
├── tests/        # Application test suite
├── docs/         # Architecture, security, runbooks, decision log
└── .github/      # Workflows, PR template, CODEOWNERS
```

## Quickstart (local, no AWS required)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
uvicorn app.main:app --reload --port 8080
curl "localhost:8080/api/v1/recommendations?style=italian&vegetarian=true"
```

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/architecture.md](docs/architecture.md) | Production architecture: AWS, EKS, GitOps, CI/CD, security, logging |
| [docs/api.md](docs/api.md) | Endpoints, parameters, examples, local run |
| [terraform/README.md](terraform/README.md) | Infrastructure: module layout, conventions, remote state |
| [docs/deployment.md](docs/deployment.md) | How deploys happen, rollback, first-time bootstrap |
| [docs/plan-approval.md](docs/plan-approval.md) | CI/CD approval gate: Environments, reviewers, artifact integrity |
| [docs/security.md](docs/security.md) | Every control by layer + accepted trade-offs |
| [docs/monitoring.md](docs/monitoring.md) | Probes, log pipeline, queries, alarms, CD verification |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Symptom-first runbook |
| [docs/teardown.md](docs/teardown.md) | Ordered decommissioning with guardrails |
| [docs/decision-log.md](docs/decision-log.md) | ADR-001–009: every non-obvious decision with alternatives |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Branch workflow, commit and PR conventions |

Per-component detail lives beside the code: each Terraform module and the
Helm chart carry their own README.

## Development workflow

All work happens on feature branches merged into a protected `main` via Pull
Request — one GitHub Issue per branch per PR. See
[CONTRIBUTING.md](CONTRIBUTING.md).
