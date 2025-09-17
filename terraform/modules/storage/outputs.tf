output "metrics_bucket_name" {
  description = "Name of the metrics S3 bucket"
  value       = local.metrics_bucket_name
}

output "metrics_bucket_arn" {
  description = "ARN of the metrics S3 bucket"
  value       = local.metrics_bucket_name == "" ? "" : "arn:aws:s3:::${local.metrics_bucket_name}"
}

output "deployment_bucket_name" {
  description = "Name of the deployment S3 bucket"
  value       = coalesce(local.deployment_bucket_name, "")
}
