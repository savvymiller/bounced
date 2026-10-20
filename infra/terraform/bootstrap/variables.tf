variable "aws_region" {
  description = "AWS region that hosts the Terraform state backend."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project name, used as a resource name/tag prefix."
  type        = string
  default     = "tapid"
}

variable "environments" {
  description = "Environment names that will each get their own state key prefix."
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "github_repository" {
  description = <<-EOT
    GitHub repository allowed to assume the deploy role via OIDC, in
    "owner/repo" form. Required — there is no safe default.
  EOT
  type        = string
}

variable "github_deploy_branches" {
  description = <<-EOT
    Git refs (branches) allowed to assume the deploy role, e.g. ["main"].
    Keep this narrow: anything that can push to one of these branches
    can deploy to every environment this role is granted access to.
  EOT
  type        = list(string)
  default     = ["main"]
}
