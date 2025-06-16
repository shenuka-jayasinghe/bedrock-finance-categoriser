# S3 Bucket for bank statements
resource "aws_s3_bucket" "statements_bucket" {
  bucket = "${local.name_prefix}-bank-statements-${random_string.bucket_suffix.result}"

  tags = local.common_tags
}

resource "aws_s3_bucket" "open_table_bucket" {
  bucket = "${local.name_prefix}-open-table-${random_string.bucket_suffix.result}"

  tags = local.common_tags
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_versioning" "statements_bucket_versioning" {
  bucket = aws_s3_bucket.statements_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "statements_bucket_encryption" {
  bucket = aws_s3_bucket.statements_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "statements_bucket_pab" {
  bucket = aws_s3_bucket.statements_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_notification" "trigger_lambda" {
  bucket = aws_s3_bucket.statements_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.statement_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""     # Optional: set if your CSVs are in a subfolder like "statements/"
    filter_suffix       = ".csv" # Optional: trigger only for .csv files
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke
  ]
}
