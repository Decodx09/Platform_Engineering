output "s3_bucket_name" {
  description = "The name of the S3 bucket created for the Terraform state."
  value       = aws_s3_bucket.tfstate.bucket
}

output "dynamodb_table_name" {
  description = "The name of the DynamoDB table for state locking."
  value       = aws_dynamodb_table.tflock.name
}
