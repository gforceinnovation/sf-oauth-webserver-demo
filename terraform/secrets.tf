# Secrets Manager for Salesforce Credentials
resource "aws_secretsmanager_secret" "sf_credentials" {
  name                    = "${var.project_name}-sf-credentials"
  description             = "Salesforce OAuth credentials for ${var.project_name}"
  recovery_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-sf-credentials"
    Environment = var.environment
  }
}

# Store the secret value
resource "aws_secretsmanager_secret_version" "sf_credentials" {
  secret_id = aws_secretsmanager_secret.sf_credentials.id
  secret_string = jsonencode({
    SF_CLIENT_ID     = var.sf_client_id
    SF_CLIENT_SECRET = var.sf_client_secret
    SF_CALLBACK_URL  = var.sf_callback_url
    SF_LOGIN_URL     = var.sf_login_url
    SESSION_SECRET   = var.session_secret
  })
}
