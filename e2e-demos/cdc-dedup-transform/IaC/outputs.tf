output "s3_bucket_name" {
  description = "Name of the S3 bucket created for Confluent Cloud sink connector"
  value       = aws_s3_bucket.confluent_sink.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.confluent_sink.arn
}

output "s3_bucket_region" {
  description = "AWS region where the S3 bucket is created"
  value       = aws_s3_bucket.confluent_sink.region
}

output "iam_user_name" {
  description = "Name of the IAM user for Confluent Cloud access"
  value       = aws_iam_user.confluent_s3_user.name
}

output "iam_user_arn" {
  description = "ARN of the IAM user"
  value       = aws_iam_user.confluent_s3_user.arn
}

output "access_key_id" {
  description = "AWS Access Key ID for Confluent Cloud S3 sink connector"
  value       = aws_iam_access_key.confluent_s3_user_key.id
}

output "secret_access_key" {
  description = "AWS Secret Access Key for Confluent Cloud S3 sink connector"
  value       = aws_iam_access_key.confluent_s3_user_key.secret
  sensitive   = true
}

output "confluent_s3_connector_config" {
  description = "Configuration values needed for Confluent Cloud S3 sink connector"
  value = {
    "s3.bucket.name"    = aws_s3_bucket.confluent_sink.bucket
    "s3.region"         = aws_s3_bucket.confluent_sink.region
    "aws.access.key.id" = aws_iam_access_key.confluent_s3_user_key.id
    "aws.secret.access.key" = aws_iam_access_key.confluent_s3_user_key.secret
  }
  sensitive = true
}
