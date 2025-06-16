resource "aws_dynamodb_table" "transactions" {
  name         = "${var.project_name}-transactions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "transaction_id"

  attribute {
    name = "transaction_id"
    type = "S"
  }

  attribute {
    name = "file_name"
    type = "S"
  }

  attribute {
    name = "processed"
    type = "S"
  }

  global_secondary_index {
    name            = "file-processed-index"
    hash_key        = "file_name"
    range_key       = "processed"
    projection_type = "ALL"
  }

  tags = {
    Name = "${var.project_name}-transactions"
  }
}



resource "aws_dynamodb_table" "categories" {
  name         = "${local.name_prefix}-categories"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "category_id"

  attribute {
    name = "category_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "statements" {
  name         = "${local.name_prefix}-statements"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "statement_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "statement_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "monthly_summaries" {
  name         = "${local.name_prefix}-monthly-summaries"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "year_month"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "year_month"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}

resource "aws_dynamodb_table" "processing_jobs" {
  name         = "${local.name_prefix}-processing-jobs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "job_id"

  attribute {
    name = "job_id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  # GSI for querying jobs by user
  global_secondary_index {
    name            = "UserJobsIndex"
    hash_key        = "user_id"
    range_key       = "job_id"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.common_tags
}
