variable "name_prefix" {
  description = "Prefix used when naming storage resources"
  type        = string
}

variable "enable_s3_storage" {
  description = "Whether to provision S3 buckets for metrics storage"
  type        = bool
}

variable "metrics_bucket_name" {
  description = "Optional name of an existing metrics bucket"
  type        = string
  default     = ""
}

variable "enable_deployment_bucket" {
  description = "Whether to create an S3 bucket for Lambda deployment packages"
  type        = bool
}

variable "deployment_bucket_name" {
  description = "Optional name for the deployment bucket"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to created S3 buckets"
  type        = map(string)
  default     = {}
}
