variable "name_prefix" {
  description = "Prefix used when naming notification resources"
  type        = string
}

variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
}

variable "notification_email" {
  description = "Optional email subscription for the SNS topic"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to SNS resources"
  type        = map(string)
  default     = {}
}
