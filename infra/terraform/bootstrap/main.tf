provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Component = "bootstrap"
    }
  }
}

data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Remote state storage
# ---------------------------------------------------------------------------
# One bucket, one lock table, shared across dev/staging/prod. Each
# environment gets its own object key (see environments/*/backend.tf), so
# a mistake in one environment's config cannot clobber another's state.

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project}-terraform-state-${data.aws_caller_identity.current.account_id}"

  # Intentionally not force_destroy: destroying this bucket destroys the
  # history of every environment's infrastructure. If it needs to go,
  # that should be a deliberate, separate action.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${var.project}-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ---------------------------------------------------------------------------
# IAM bootstrap: let GitHub Actions deploy without long-lived AWS keys
# ---------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = []
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [for b in var.github_deploy_branches : "repo:${var.github_repository}:ref:refs/heads/${b}"]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name                 = "${var.project}-github-actions-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_actions_trust.json
  max_session_duration = 3600
}

# Deliberately scoped to the services this project actually uses
# (ADR-0006), rather than a managed admin policy. Expect to extend this
# as new modules land (Lambda, API Gateway, EventBridge, AppConfig,
# Firehose/Glue/Athena) — each addition should be a reviewable diff
# here, not a blanket grant up front.
data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid    = "TerraformState"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]
  }

  statement {
    sid    = "TerraformLock"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
    ]
    resources = [aws_dynamodb_table.terraform_lock.arn]
  }

  statement {
    sid    = "ProjectDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:UpdateTable",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:ListTagsOfResource",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:DescribeContinuousBackups",
    ]
    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${var.project}-main*"]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "${var.project}-deploy-scope"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}
