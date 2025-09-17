variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used to name Terraform-managed resources"
  type        = string
  default     = "connect-quota-monitor"
}

variable "threshold_percentage" {
  description = "Percentage threshold for quota utilization alerts (1-99%)"
  type        = number
  default     = 80
  validation {
    condition     = var.threshold_percentage >= 1 && var.threshold_percentage <= 99
    error_message = "threshold_percentage must be between 1 and 99."
  }
}

variable "schedule_expression" {
  description = "Schedule expression for automated Lambda execution"
  type        = string
  default     = "rate(1 hour)"
}

variable "notification_email" {
  description = "Optional email address for quota alerts"
  type        = string
  default     = ""
}

variable "sns_topic_name" {
  description = "Name of the SNS topic for alerts"
  type        = string
  default     = "ConnectQuotaAlerts"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 600
}

variable "lambda_memory" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 512
}

variable "lambda_runtime" {
  description = "Python runtime version for the Lambda function"
  type        = string
  default     = "python3.12"
  validation {
    condition     = contains(["python3.10", "python3.11", "python3.12"], var.lambda_runtime)
    error_message = "lambda_runtime must be python3.10, python3.11, or python3.12."
  }
}

variable "deployment_method" {
  description = "Lambda deployment method. Use 'placeholder' for local packaging or 's3' for pre-uploaded code."
  type        = string
  default     = "placeholder"
  validation {
    condition     = contains(["placeholder", "s3"], var.deployment_method)
    error_message = "deployment_method must be either 'placeholder' or 's3'."
  }
}

variable "use_s3_storage" {
  description = "Enable S3 storage for metrics and reports"
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Optional custom S3 bucket name for metrics and reports"
  type        = string
  default     = ""
}

variable "use_dynamodb_storage" {
  description = "Enable DynamoDB storage for metrics"
  type        = bool
  default     = true
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = "ConnectQuotaMonitor"
}

variable "create_deployment_bucket" {
  description = "Create an S3 bucket for Lambda deployment packages"
  type        = bool
  default     = true
}

variable "deployment_bucket_name" {
  description = "Optional name for an existing or custom deployment bucket"
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "Optional VPC ID for the Lambda function"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Optional subnet IDs for VPC deployment"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to supported resources"
  type        = map(string)
  default     = {}
}
