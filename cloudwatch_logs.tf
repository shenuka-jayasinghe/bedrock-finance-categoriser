resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.name_prefix}-statement-processor"
  retention_in_days = var.lambda_log_retention_days

  tags = local.common_tags
}