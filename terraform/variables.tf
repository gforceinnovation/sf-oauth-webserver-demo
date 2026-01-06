variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "sf-oauth-demo"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "sf_client_id" {
  description = "Salesforce Connected App Consumer Key"
  type        = string
  sensitive   = true
}

variable "sf_client_secret" {
  description = "Salesforce Connected App Consumer Secret"
  type        = string
  sensitive   = true
}

variable "sf_callback_url" {
  description = "Salesforce OAuth Callback URL"
  type        = string
}

variable "sf_login_url" {
  description = "Salesforce Login URL"
  type        = string
  default     = "https://login.salesforce.com"
}

variable "container_image" {
  description = "Docker image URI in ECR"
  type        = string
}

variable "session_secret" {
  description = "Session secret for Express sessions"
  type        = string
  sensitive   = true
}
