output "state_bucket" {
  description = "S3 bucket holding every environment's Terraform state."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "lock_table" {
  description = "DynamoDB table used for Terraform state locking."
  value       = aws_dynamodb_table.terraform_lock.name
}

output "github_actions_deploy_role_arn" {
  description = "Role ARN for GitHub Actions to assume via OIDC (set as the AWS_DEPLOY_ROLE_ARN repo/environment secret)."
  value       = aws_iam_role.github_actions_deploy.arn
}
