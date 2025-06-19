# Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for bank statements"
  value       = aws_s3_bucket.statements_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for bank statements"
  value       = aws_s3_bucket.statements_bucket.arn
}

output "lambda_function_name" {
  description = "Name of the statement processor Lambda function"
  value       = aws_lambda_function.statement_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the statement processor Lambda function"
  value       = aws_lambda_function.statement_processor.arn
}

output "dynamodb_table_names" {
  description = "Names of all DynamoDB tables"
  value = {
    transactions      = aws_dynamodb_table.transactions.name
    categories        = aws_dynamodb_table.categories.name
    statements        = aws_dynamodb_table.statements.name
    monthly_summaries = aws_dynamodb_table.monthly_summaries.name
    processing_jobs   = aws_dynamodb_table.processing_jobs.name
  }
}

output "textract_service_role_arn" {
  description = "ARN of the Textract service role"
  value       = aws_iam_role.textract_service_role.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "open_table_bucket_name" {
  description = "Name of the S3 bucket for open table format (Athena queries)"
  value       = aws_s3_bucket.open_table_bucket.id
}

output "open_table_bucket_arn" {
  description = "ARN of the S3 bucket for open table format (Athena queries)"
  value       = aws_s3_bucket.open_table_bucket.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.transaction_processor.arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.transaction_processor.repository_url
}
