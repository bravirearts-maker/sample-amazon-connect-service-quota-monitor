variable "stack_name" {
  description = "Name prefix applied to all resources to retain parity with the CloudFormation template."
  type        = string
}

variable "threshold_percentage" {
  type        = number
  description = "Percentage threshold for quota utilisation alerts."
}

variable "lambda_timeout" {
  type        = number
  description = "Lambda timeout in seconds."
}

variable "lambda_memory" {
  type        = number
  description = "Lambda memory size in MB."
}

variable "lambda_runtime" {
  type        = string
  description = "Lambda runtime version."
}

variable "schedule_expression" {
  type        = string
  description = "CloudWatch Events schedule expression for the monitor."
}

variable "notification_email" {
  type        = string
  description = "Optional notification email for SNS subscription."
  default     = ""
}

variable "use_s3_storage" {
  type        = bool
  description = "Whether to enable S3 storage for metrics and reports."
}

variable "s3_bucket_name" {
  type        = string
  description = "Existing S3 bucket name for metrics storage."
  default     = ""
}

variable "use_dynamodb_storage" {
  type        = bool
  description = "Whether to enable DynamoDB storage."
}

variable "dynamodb_table_name" {
  type        = string
  description = "Name of the DynamoDB table used when storage is enabled."
}

variable "sns_topic_name" {
  type        = string
  description = "SNS topic name for alerts."
}

variable "create_deployment_bucket" {
  type        = bool
  description = "Whether to create and manage a deployment bucket."
}

variable "deployment_bucket_name" {
  type        = string
  description = "Optional existing or custom deployment bucket name."
  default     = ""
}

variable "deployment_method" {
  type        = string
  description = "Deployment method for the Lambda function (inline or s3)."
}

variable "vpc_id" {
  type        = string
  description = "Optional VPC ID for the Lambda function."
  default     = ""
}

variable "subnet_ids" {
  type        = list(string)
  description = "Optional subnet IDs for the Lambda function when a VPC is supplied."
  default     = []
}

variable "account_id" {
  type        = string
  description = "AWS account ID used for naming defaults."
}

variable "region" {
  type        = string
  description = "AWS region where resources are created."
}
