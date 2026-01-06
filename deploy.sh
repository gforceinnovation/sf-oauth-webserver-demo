#!/bin/bash

# Salesforce OAuth Demo - Quick Deployment Script
# This script automates the AWS deployment process

set -e  # Exit on error

echo "🚀 Salesforce OAuth Demo - AWS Deployment Script"
echo "=================================================="
echo ""

# Check prerequisites
command -v aws >/dev/null 2>&1 || { echo "❌ AWS CLI is required but not installed. Aborting." >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed. Aborting." >&2; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed. Aborting." >&2; exit 1; }

echo "✅ Prerequisites check passed"
echo ""

# Get AWS account info
echo "📋 Getting AWS account information..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${AWS_REGION:-us-east-1}

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo ""

# Build Docker image
echo "🐳 Building Docker image..."
docker build -t sf-oauth-demo .
echo "✅ Docker image built successfully"
echo ""

# Login to ECR
echo "🔐 Logging in to Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
echo "✅ Logged in to ECR"
echo ""

# Check if ECR repository exists, create if not
echo "📦 Checking ECR repository..."
if ! aws ecr describe-repositories --repository-names sf-oauth-demo --region $AWS_REGION >/dev/null 2>&1; then
  echo "Creating ECR repository..."
  aws ecr create-repository --repository-name sf-oauth-demo --region $AWS_REGION
  echo "✅ ECR repository created"
else
  echo "✅ ECR repository already exists"
fi
echo ""

# Tag and push image
echo "📤 Pushing Docker image to ECR..."
ECR_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/sf-oauth-demo"
docker tag sf-oauth-demo:latest $ECR_REPO:latest
docker push $ECR_REPO:latest
echo "✅ Image pushed to ECR: $ECR_REPO:latest"
echo ""

# Check if terraform.tfvars exists
if [ ! -f terraform/terraform.tfvars ]; then
  echo "⚠️  terraform.tfvars not found!"
  echo "Please create terraform/terraform.tfvars from terraform.tfvars.example"
  echo "and fill in your Salesforce credentials."
  echo ""
  echo "Update the container_image variable to: $ECR_REPO:latest"
  exit 1
fi

# Deploy with Terraform
echo "🏗️  Deploying infrastructure with Terraform..."
cd terraform

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Plan
echo "Creating deployment plan..."
terraform plan -out=tfplan

# Ask for confirmation
read -p "Do you want to apply this plan? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "❌ Deployment cancelled"
  exit 1
fi

# Apply
echo "Applying infrastructure..."
terraform apply tfplan

# Get outputs
echo ""
echo "=================================================="
echo "✅ Deployment Complete!"
echo "=================================================="
echo ""
terraform output

echo ""
echo "📝 Next Steps:"
echo "1. Update your Salesforce Connected App callback URL with the ALB URL above"
echo "2. Update terraform/terraform.tfvars with the correct callback URL"
echo "3. Run: terraform apply"
echo "4. Force new ECS deployment:"
echo "   aws ecs update-service --cluster sf-oauth-demo-cluster \\"
echo "     --service sf-oauth-demo-service --force-new-deployment"
echo ""
echo "🎉 Your application will be live in 2-3 minutes!"
