terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Deliberately local state. This module creates the S3 bucket and
  # DynamoDB table that every environment's remote backend depends on,
  # so it cannot depend on a remote backend itself — the classic
  # bootstrap chicken-and-egg problem.
  #
  # Run this once per AWS account (not per environment), by hand, and
  # keep the resulting terraform.tfstate somewhere durable and
  # access-controlled (e.g. a password manager or a bucket created
  # out-of-band) — see README.md in this directory.
}
