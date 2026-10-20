terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Partial configuration: the bucket name is account-specific (it
  # includes the AWS account ID) and so cannot be a literal here. Supply
  # it at init time:
  #
  #   terraform init -backend-config=backend.hcl
  #
  # See ../../README.md for how to generate backend.hcl from the
  # bootstrap module's outputs.
  backend "s3" {
    key            = "tapid/dev/terraform.tfstate"
    dynamodb_table = "tapid-terraform-lock"
    encrypt        = true
  }
}
