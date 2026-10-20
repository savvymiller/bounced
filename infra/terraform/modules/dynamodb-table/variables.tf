variable "project" {
  description = "Short project name, used as a resource name prefix."
  type        = string
  default     = "tapid"
}

variable "environment" {
  description = "Environment name (dev/staging/prod). Used as a tag."
  type        = string
}

variable "deletion_protection_enabled" {
  description = "Prevent the table from being deleted via the AWS API/Terraform. Should be true everywhere except throwaway dev stacks."
  type        = bool
  default     = true
}

variable "point_in_time_recovery" {
  description = "Enable continuous backups (PITR). This is the audit-record table (docs/DATA_MODEL.md) — keep true outside of short-lived dev stacks."
  type        = bool
  default     = true
}
