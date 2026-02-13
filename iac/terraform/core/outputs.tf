output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.claims.name
}

output "claim_notes_bucket_name" {
  description = "Name of the S3 bucket for claim notes"
  value       = aws_s3_bucket.claim_notes.id
}

output "claim_notes_bucket_arn" {
  description = "ARN of the S3 bucket for claim notes"
  value       = aws_s3_bucket.claim_notes.arn
}

output "config_bucket_name" {
  description = "S3 bucket used for AWS Config snapshots"
  value       = data.aws_s3_bucket.config.id
}

output "config_recorder_name" {
  description = "AWS Config recorder name"
  value       = aws_config_configuration_recorder.this.name
}
