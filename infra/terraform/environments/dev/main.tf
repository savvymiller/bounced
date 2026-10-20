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

module "dynamodb_table" {
  source = "../../modules/dynamodb-table"

  project     = var.project
  environment = var.environment

  # Non-prod: cheaper and faster to tear down/recreate while the
  # schema is still settling.
  deletion_protection_enabled = false
  point_in_time_recovery      = false
}
