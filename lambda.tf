resource "aws_lambda_function" "statement_processor" {
  function_name = "${local.name_prefix}-statement-processor"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 256

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ECS_CLUSTER_ARN     = aws_ecs_cluster.main.arn
      TASK_DEFINITION_ARN = aws_ecs_task_definition.transaction_processor.arn
      SUBNETS             = join(",", data.aws_subnets.default.ids)
      SECURITY_GROUP      = aws_security_group.ecs_tasks.id
      DYNAMODB_TABLE      = aws_dynamodb_table.transactions.name
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.statement_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.statements_bucket.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_function.zip"
}
