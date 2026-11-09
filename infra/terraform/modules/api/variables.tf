variable "project" {
  description = "Short project name, used as a resource name/tag prefix."
  type        = string
}

variable "environment" {
  description = "Environment name. Used as a tag and in resource names."
  type        = string
}

variable "table_name" {
  description = "Name of the tapid-main DynamoDB table the Lambda writes to."
  type        = string
}

variable "table_arn" {
  description = "ARN of the tapid-main DynamoDB table, for the Lambda's IAM policy."
  type        = string
}

variable "lambda_source_dir" {
  description = "Path to the Lambda handler source (services/api/lambda)."
  type        = string
}

variable "demo_api_token" {
  description = <<-EOT
    Static bearer token the demo client authenticates with. Stands in for
    the App Attest + Cognito device auth in docs/API.md, which needs a real
    enrolled device and is out of scope until the Apple entitlement lands
    (docs/DELIVERY_PLAN.md Track D/F). Not a production credential.
  EOT
  type        = string
  sensitive   = true
}
