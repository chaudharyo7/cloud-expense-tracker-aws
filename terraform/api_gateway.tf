resource "aws_apigatewayv2_api" "expense_api" {
  name          = "expense-tracker-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["content-type", "authorization"]
    allow_methods = ["POST", "OPTIONS"]
    allow_origins = ["https://projects.yamandeep.in", "http://localhost", "http://127.0.0.1"]
    max_age       = 3600
  }

  tags = {
    Name = "expense-tracker-api"
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id = aws_apigatewayv2_api.expense_api.id

  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.expense_lambda.invoke_arn
  integration_method = "POST"
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.expense_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.expense_api.execution_arn}/*/POST/reports"
}

resource "aws_apigatewayv2_route" "generate_report" {
  api_id = aws_apigatewayv2_api.expense_api.id

  route_key = "POST /reports"

  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

  authorization_type = "NONE"
}

resource "aws_cloudwatch_log_group" "api_gw_access_logs" {
  name              = "/aws/apigateway/expense-tracker"
  retention_in_days = 14

  tags = {
    Name = "expense-tracker-api-access-logs"
  }
}

resource "aws_cloudwatch_log_resource_policy" "api_gw_cw_logs_policy" {
  policy_name = "expense-tracker-apigw-cw-logs-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "APIGatewayAccessLogsDelivery"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.api_gw_access_logs.arn}:*"
      }
    ]
  })
}

resource "aws_apigatewayv2_stage" "expense_api_stage" {
  api_id = aws_apigatewayv2_api.expense_api.id

  name = "$default"

  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 10
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw_access_logs.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      responseLatency         = "$context.responseLatency"
      integrationLatency      = "$context.integrationLatency"
      integrationStatus       = "$context.integrationStatus"
      integrationErrorMessage = "$context.integrationErrorMessage"
      authorizerError         = "$context.authorizer.error"
      errorMessage            = "$context.error.message"
    })
  }

  depends_on = [aws_cloudwatch_log_group.api_gw_access_logs]
}
