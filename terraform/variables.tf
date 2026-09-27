variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "ap-south-1"
}

variable "db_username" {
  description = "Username for the database admin"
  type        = string
  default     = "expense_user"
  sensitive   = true

}

variable "project_suffix" {
  type    = string
  default = "yd2026"
}

variable "github_repository" {
  description = "GitHub repository in owner/repository format or explicit OIDC sub claim"
  type        = string
  default     = "chaudharyo7@120274838/cloud-expense-tracker-aws@1390969201"
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for the HTTPS Application Load Balancer listener"
  type        = string
}

variable "alert_email" {
  description = "Optional email address to receive CloudWatch alarm notifications via SNS"
  type        = string
  default     = ""
}
