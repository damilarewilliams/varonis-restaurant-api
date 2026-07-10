# ecr module

Private container registry for the API image, with security and cost
controls built in.

## Design decisions

- **ECR over Docker Hub** (ADR-007): IAM-native auth (the CI OIDC role and
  node role pull without stored credentials), no rate limits, VPC-endpoint
  reachable (image pulls never cross the public internet), scan-on-push.
- **Immutable tags**: a pushed tag can never point at different bytes,
  which is what makes GitOps rollback (revert values.yaml) trustworthy.
- **Scan-on-push** as the second scanning layer: Trivy gates the pipeline
  before push; ECR re-evaluates stored images as new CVEs publish.
- **AES256 encryption** rather than a customer KMS key: images are not
  secret material; CMKs are reserved for data/logs (Issue #9/#11).
- **Lifecycle policy**: untagged images expire in 7 days; only the last
  `max_image_count` (default 20) tagged images are retained - a bounded
  rollback window instead of unbounded storage spend.

## Inputs

| Name | Description | Default |
|------|-------------|---------|
| project / environment | Naming and tags | - |
| max_image_count | Tagged images retained | `20` |

## Outputs

repository_url (docker push / Helm image.repository), repository_arn
(IAM policies), repository_name.

## Usage

```hcl
module "ecr" {
  source = "../../modules/ecr"

  project     = var.project
  environment = var.environment
}
```
