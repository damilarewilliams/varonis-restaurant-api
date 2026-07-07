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

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/architecture.md](docs/architecture.md) | System design and end-to-end flow |
| [docs/decision-log.md](docs/decision-log.md) | Every non-obvious technical decision (ADRs) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Branch workflow, commit and PR conventions |

Additional docs (infrastructure, API, security, deployment, CI/CD, GitOps,
monitoring, troubleshooting) are added under `docs/` as each area is built —
tracked in the [GitHub Issues](https://github.com/damilarewilliams/varonis-restaurant-api/issues).

## Development workflow

All work happens on feature branches merged into a protected `main` via Pull
Request — one GitHub Issue per branch per PR. See
[CONTRIBUTING.md](CONTRIBUTING.md).
