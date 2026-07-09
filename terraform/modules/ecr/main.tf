# Module: ecr
# Private container registry for the API image.

locals {
  repository_name = "${var.project}-${var.environment}"
}

resource "aws_ecr_repository" "this" {
  name = local.repository_name

  # Immutable tags: a pushed tag can never be overwritten. This is what
  # makes GitOps rollback trustworthy — the tag in values.yaml always
  # points at the same bytes. Overwritable tags would let "rollback"
  # silently deploy different content.
  image_tag_mutability = "IMMUTABLE"

  # Registry-side scanning on every push — second scan layer after the
  # pipeline's Trivy gate (defense in depth: Trivy blocks the pipeline,
  # ECR keeps re-evaluating stored images as new CVEs are published).
  image_scanning_configuration {
    scan_on_push = true
  }

  # AES256 = AWS-managed encryption at rest, always on, no key to manage.
  # A customer-managed KMS key adds per-request KMS cost and rotation
  # ops for images that are not secret material — the CMKs (Issue #9)
  # are reserved for data and logs, which ARE sensitive.
  encryption_configuration {
    encryption_type = "AES256"
  }

  # Refuse to delete a repository that still contains images.
  force_delete = false
}

# Bound storage growth: keep recent releases for rollback, expire the rest.
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 7 days (failed/interrupted pushes)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep only the last ${var.max_image_count} tagged images"
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = var.max_image_count
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}
