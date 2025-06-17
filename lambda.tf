# # Step 1: Create a placeholder Lambda function first
# resource "aws_lambda_function" "statement_processor" {
#   function_name = "${local.name_prefix}-statement-processor"
#   role          = aws_iam_role.lambda_execution_role.arn
#   handler       = "lambda_function.lambda_handler"
#   runtime       = "python3.11"
#   timeout       = 900
#   memory_size   = 1024

#   # Inline code as placeholder
#   filename = "${path.module}/lambda_function.zip"

#   environment {
#     variables = {
#       TRANSACTIONS_TABLE      = aws_dynamodb_table.transactions.name
#       CATEGORIES_TABLE        = aws_dynamodb_table.categories.name
#       STATEMENTS_TABLE        = aws_dynamodb_table.statements.name
#       MONTHLY_SUMMARIES_TABLE = aws_dynamodb_table.monthly_summaries.name
#       PROCESSING_JOBS_TABLE   = aws_dynamodb_table.processing_jobs.name
#       BEDROCK_MODEL_ID        = var.bedrock_model_id
#       TEXTRACT_ROLE_ARN       = aws_iam_role.textract_service_role.arn
#       OPEN_TABLE_BUCKET       = aws_s3_bucket.open_table_bucket.bucket
#       DYNAMODB_TABLE          = aws_dynamodb_table.transactions.name
#     }
#   }

#   tags = local.common_tags

#   lifecycle {
#     ignore_changes = [
#       filename,
#       source_code_hash,
#       last_modified
#     ]
#   }
#   source_code_hash = data.archive_file.lambda_zip.output_base64sha256
# }

# # # Step 2: Build and deploy the actual Lambda package
# # resource "null_resource" "lambda_build_and_deploy" {
# #   # depends_on = [aws_lambda_function.statement_processor]

# #   provisioner "local-exec" {
# #     command = <<EOF
# # cd ${path.module}/lambda/lambda-deployment
# # cp ../lambda_deployment.py .
# # pip install pandas boto3 -t .
# # zip -r lambda_function.zip .
# # EOF
# #   }

# #   triggers = {
# #     lambda_code = filemd5("${path.module}/lambda/lambda_function.py")
# #   }
# # }

# # Lambda permission to allow S3 to invoke the function
# resource "aws_lambda_permission" "allow_s3_invoke" {
#   statement_id  = "AllowExecutionFromS3Bucket"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.statement_processor.function_name
#   principal     = "s3.amazonaws.com"
#   source_arn    = aws_s3_bucket.statements_bucket.arn
# }

# data "archive_file" "lambda_zip" {
#   type        = "zip"
#   source_dir  = "${path.module}/lambda"
#   output_path = "${path.module}/lambda_function.zip"

# }