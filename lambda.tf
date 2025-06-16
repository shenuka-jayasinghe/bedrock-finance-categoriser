# Lambda function
resource "aws_lambda_function" "statement_processor" {
  depends_on    = [null_resource.lambda_dependencies]
  filename      = "${path.module}/lambda_function.zip"
  function_name = "${local.name_prefix}-statement-processor"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 900 # 15 minutes
  memory_size   = 1024

  environment {
    variables = {
      TRANSACTIONS_TABLE      = aws_dynamodb_table.transactions.name
      CATEGORIES_TABLE        = aws_dynamodb_table.categories.name
      STATEMENTS_TABLE        = aws_dynamodb_table.statements.name
      MONTHLY_SUMMARIES_TABLE = aws_dynamodb_table.monthly_summaries.name
      PROCESSING_JOBS_TABLE   = aws_dynamodb_table.processing_jobs.name
      BEDROCK_MODEL_ID        = var.bedrock_model_id
      TEXTRACT_ROLE_ARN       = aws_iam_role.textract_service_role.arn
      OPEN_TABLE_BUCKET       = aws_s3_bucket.open_table_bucket.bucket
    }
  }

  tags = local.common_tags
}


# Lambda permission to allow S3 to invoke the function
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.statement_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.statements_bucket.arn
}

# Create Lambda deployment package
resource "null_resource" "lambda_dependencies" {
  provisioner "local-exec" {
    command = <<EOF
cd lambda
rm -rf lambda_package
mkdir -p lambda_package
cp lambda_function.py lambda_package/
pip install \
  --platform manylinux2014_x86_64 \
  --implementation cp \
  --python-version 3.11 \
  --only-binary=:all: \
  --upgrade \
  boto3 pandas \
  -t lambda_package/
cd lambda_package && zip -r ../../lambda_function.zip . -i .
EOF
  }

  triggers = {
    lambda_code = filemd5("${path.module}/lambda/lambda_function.py")
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/lambda_package"
  output_path = "lambda_function.zip"
  depends_on  = [null_resource.lambda_dependencies]
}
