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
        "dynamodb:Query",
        "dynamodb:Scan"
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

resource "aws_api_gateway_method" "options_transaction" {
  rest_api_id   = aws_api_gateway_rest_api.transactions_api.id
  resource_id   = aws_api_gateway_resource.transaction.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_transaction" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transaction.id
  http_method = aws_api_gateway_method.options_transaction.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }
}

resource "aws_api_gateway_method_response" "options_transaction" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transaction.id
  http_method = aws_api_gateway_method.options_transaction.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_transaction" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transaction.id
  http_method = aws_api_gateway_method.options_transaction.http_method
  status_code = aws_api_gateway_method_response.options_transaction.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
  }

  response_templates = {
    "application/json" = ""
  }
}

resource "aws_api_gateway_resource" "transactions" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  parent_id   = aws_api_gateway_rest_api.transactions_api.root_resource_id
  path_part   = "transactions"
}

resource "aws_api_gateway_method" "options_transactions" {
  rest_api_id   = aws_api_gateway_rest_api.transactions_api.id
  resource_id   = aws_api_gateway_resource.transactions.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_transactions" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transactions.id
  http_method = aws_api_gateway_method.options_transactions.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }
}

resource "aws_api_gateway_method_response" "options_transactions" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transactions.id
  http_method = aws_api_gateway_method.options_transactions.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_transactions" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transactions.id
  http_method = aws_api_gateway_method.options_transactions.http_method
  status_code = aws_api_gateway_method_response.options_transactions.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
  }

  response_templates = {
    "application/json" = ""
  }
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

resource "aws_api_gateway_method" "list_transactions" {
  rest_api_id   = aws_api_gateway_rest_api.transactions_api.id
  resource_id   = aws_api_gateway_resource.transactions.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "list_transactions" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transactions.id
  http_method = aws_api_gateway_method.list_transactions.http_method

  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:dynamodb:action/Scan"
  credentials             = aws_iam_role.apigw_dynamodb_role.arn

  request_templates = {
    "application/json" = <<TEMPLATE
{
  "TableName": "${aws_dynamodb_table.transactions.name}"
}
TEMPLATE
  }
}

resource "aws_api_gateway_method_response" "list_transactions" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transactions.id
  http_method = aws_api_gateway_method.list_transactions.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "list_transactions" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transactions.id
  http_method = aws_api_gateway_method.list_transactions.http_method
  status_code = aws_api_gateway_method_response.list_transactions.status_code

  response_templates = {
    "application/json" = ""
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
  }
}

resource "aws_api_gateway_method_response" "get_transaction" {
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  resource_id = aws_api_gateway_resource.transaction.id
  http_method = aws_api_gateway_method.get_transaction.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
  }

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

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Headers" = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
  }
}

resource "aws_api_gateway_deployment" "transactions_api" {
  depends_on = [
    aws_api_gateway_integration.get_transaction,
    aws_api_gateway_integration.list_transactions,
    aws_api_gateway_integration.options_transactions,
    aws_api_gateway_integration.options_transaction
  ]
  rest_api_id = aws_api_gateway_rest_api.transactions_api.id
  stage_name  = var.environment
}

