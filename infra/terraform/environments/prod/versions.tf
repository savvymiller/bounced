terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Partial configuration — see environments/dev/versions.tf for why,
  # and ../../README.md for how to generate backend.hcl.
  backend "s3" {
    key            = "tapid/prod/terraform.tfstate"
    dynamodb_table = "tapid-terraform-lock"
    encrypt        = true
  }
}
