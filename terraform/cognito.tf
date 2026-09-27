resource "aws_cognito_user_pool" "expense_user_pool" {
  name = "expense-user-pool-${var.project_suffix}"

  # Allow users to sign in with their email address
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Your Verification Code - Cloud Expense Tracker"
    email_message        = "Your verification code is {####}."
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  tags = {
    Name = "expense-user-pool-${var.project_suffix}"
  }
}

resource "aws_cognito_user_pool_client" "expense_client" {
  name         = "expense-frontend-client-${var.project_suffix}"
  user_pool_id = aws_cognito_user_pool.expense_user_pool.id

  # Public client for Single Page Application (SPA); client secret cannot be protected in browser
  generate_secret = false

  # Authentication flows supported for SPA:
  # - ALLOW_USER_SRP_AUTH: Cryptographically secure (SRP) where password is never sent in plaintext
  # - ALLOW_USER_PASSWORD_AUTH: Direct authentication over HTTPS for lightweight Vanilla JS fetch without heavyweight SDKs
  # - ALLOW_REFRESH_TOKEN_AUTH: Allows silent refresh of expired short-lived tokens using refresh token
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Prevent user enumeration attacks by returning generic error messages
  prevent_user_existence_errors = "ENABLED"

  # Short-lived access & ID tokens for security; standard refresh token lifetime
  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  enable_token_revocation = true
}

resource "aws_apigatewayv2_authorizer" "cognito_jwt" {
  api_id           = aws_apigatewayv2_api.expense_api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt-authorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.expense_client.id]
    issuer   = "https://${aws_cognito_user_pool.expense_user_pool.endpoint}"
  }
}
