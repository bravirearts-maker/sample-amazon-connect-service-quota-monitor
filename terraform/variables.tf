variable "region" {
  description = "AWS region to deploy the Connect quota monitor into."
  type        = string
}

variable "stack_name" {
  description = "Prefix used for resources to mimic the original CloudFormation stack name."
  type        = string
  default     = "connect-quota-monitor"
}

variable "threshold_percentage" {
  description = "Percentage threshold that triggers quota utilisation alerts."
  type        = number
  default     = 80
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 600
}

variable "lambda_memory" {
  description = "Amount of memory in MB allocated to the Lambda function."
  type        = number
  default     = 512
}

variable "lambda_runtime" {
  description = "Runtime version for the Lambda function."
  type        = string
  default     = "python3.12"
}

variable "schedule_expression" {
  description = "CloudWatch Events schedule expression that triggers the monitor."
  type        = string
  default     = "rate(1 hour)"
}

variable "notification_email" {
  description = "Optional email address that receives SNS notifications. Leave empty to skip subscription."
  type        = string
  default     = ""
}

variable "use_s3_storage" {
  description = "Enable S3 storage for reports and metrics."
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Existing S3 bucket name to store reports. Leave empty to create a new bucket when S3 storage is enabled."
  type        = string
  default     = ""
}

variable "use_dynamodb_storage" {
  description = "Enable DynamoDB storage for quota snapshots."
  type        = bool
  default     = true
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table used when storage is enabled."
  type        = string
  default     = "ConnectQuotaMonitor"
}

variable "sns_topic_name" {
  description = "Name of the SNS topic that delivers quota alerts."
  type        = string
  default     = "ConnectQuotaAlerts"
}

variable "create_deployment_bucket" {
  description = "Create a dedicated S3 bucket for Lambda deployment packages."
  type        = bool
  default     = true
}

variable "deployment_bucket_name" {
  description = "Optional custom deployment bucket name. Leave empty to auto-generate when creating the bucket."
  type        = string
  default     = ""
}

variable "deployment_method" {
  description = "Lambda deployment method. Use 'inline' to deploy from the local package or 's3' to upload the artifact to S3."
  type        = string
  default     = "inline"
  validation {
    condition     = contains(["inline", "s3"], var.deployment_method)
    error_message = "deployment_method must be either 'inline' or 's3'."
  }
}

variable "vpc_id" {
  description = "Optional VPC ID for deploying the Lambda function."
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Lambda function when a VPC is specified."
  type        = list(string)
  default     = []
}
