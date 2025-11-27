# AWS Cognito User Pool for employee authentication
resource "aws_cognito_user_pool" "employees" {
  name = "${var.project}-employees"

  # Allow login with email
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Strong password policy
  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Use Cognito's default email service
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # User attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = false
  }

  schema {
    name                = "department"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  schema {
    name                = "given_name"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }

  tags = {
    Name = "${var.project}-user-pool"
  }
}

# App client for HR portal
resource "aws_cognito_user_pool_client" "hr_portal" {
  name         = "${var.project}-hr-portal"
  user_pool_id = aws_cognito_user_pool.employees.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

# Create user groups
resource "aws_cognito_user_group" "hr_admins" {
  name         = "hr-admins"
  user_pool_id = aws_cognito_user_pool.employees.id
  description  = "HR administrators with full access"
  precedence   = 1
}

resource "aws_cognito_user_group" "employees_group" {
  name         = "employees"
  user_pool_id = aws_cognito_user_pool.employees.id
  description  = "Regular employees with standard access"
  precedence   = 2
}

# Outputs
output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.employees.id
  description = "Cognito User Pool ID for employee authentication"
}

output "cognito_client_id" {
  value       = aws_cognito_user_pool_client.hr_portal.id
  description = "Cognito App Client ID for HR portal"
}

output "cognito_info" {
  value = {
    user_pool_id = aws_cognito_user_pool.employees.id
    client_id    = aws_cognito_user_pool_client.hr_portal.id
    region       = var.aws_region
  }
  description = "Complete Cognito configuration"
}