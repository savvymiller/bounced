provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# No functional resources yet. This environment exists so CI and
# `terraform apply` have somewhere real to target starting now, per
# docs/DELIVERY_PLAN.md (Milestone A: "empty but real infrastructure
# deploying from CI to dev"). PR-04 adds the first resource (the
# tapid-main DynamoDB table).
