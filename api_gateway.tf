# API Gateway for accessing DynamoDB transactions table

resource "aws_iam_role" "apigw_dynamodb_role" {
  name = "${local.name_prefix}-apigw-dynamodb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "apigw_dynamodb_policy" {
  name = "${local.name_prefix}-apigw-dynamodb-policy"
  role = aws_iam_role.apigw_dynamodb_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query"
      ],
      Resource = aws_dynamodb_table.transactions.arn
    }]
  })
}

resource "aws_api_gateway_rest_api" "transactions_api" {
  name = "${local.name_prefix}-transactions-api"
}

resource "aws_api_gateway_resource" "transaction" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  parent_id   = aws_api_gateway_rest_api.transactions_api.root_resource_id
  path_part   = "transaction"
}

resource "aws_api_gateway_method" "get_transaction" {
  rest_api_id   = aws_api_gateway_rest_api.transactions_api.id
  resource_id   = aws_api_gateway_resource.transaction.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_transaction" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transaction.id
  http_method = aws_api_gateway_method.get_transaction.http_method

  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:dynamodb:action/GetItem"
  credentials             = aws_iam_role.apigw_dynamodb_role.arn

  request_templates = {
    "application/json" = <<TEMPLATE
{
  "TableName": "${aws_dynamodb_table.transactions.name}",
  "Key": {
    "transaction_id": { "S": "$input.params('transaction_id')" }
  }
}
TEMPLATE
  }
}

resource "aws_api_gateway_method_response" "get_transaction" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transaction.id
  http_method = aws_api_gateway_method.get_transaction.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "get_transaction" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transaction.id
  http_method = aws_api_gateway_method.get_transaction.http_method
  status_code = aws_api_gateway_method_response.get_transaction.status_code

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_deployment" "transactions_api" {
  depends_on = [aws_api_gateway_integration.get_transaction]
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  stage_name  = var.environment
}

