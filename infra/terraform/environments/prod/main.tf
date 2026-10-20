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

  deletion_protection_enabled = true
  point_in_time_recovery      = true
}
