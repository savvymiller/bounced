variable "aws_region" {
  description = "AWS region for this environment's resources."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name. Used as a tag and in resource names."
  type        = string
  default     = "staging"
}

variable "project" {
  description = "Short project name, used as a resource name/tag prefix."
  type        = string
  default     = "tapid"
}
