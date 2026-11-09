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
  description = "Static bearer token the demo client authenticates with. Not a production credential."
  type        = string
  sensitive   = true
}
