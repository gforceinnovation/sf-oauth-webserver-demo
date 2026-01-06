# AWS ECS Deployment Guide

This guide walks you through deploying the Salesforce OAuth Demo to AWS ECS (Fargate) with proper security practices.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Step-by-Step Deployment](#step-by-step-deployment)
- [Static IP for Salesforce Callback](#static-ip-for-salesforce-callback)
- [Security Best Practices](#security-best-practices)
- [Cost Management](#cost-management)
- [Teardown Instructions](#teardown-instructions)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

The deployment uses the following AWS services:

```
┌─────────────────────────────────────────────────────┐
│                  Internet                            │
└──────────────────┬──────────────────────────────────┘
                   │
           ┌───────▼────────┐
           │  Application   │  ← Static DNS Name
           │ Load Balancer  │     (for Salesforce callback)
           │   (Public)     │
           └───────┬────────┘
                   │
    ┌──────────────┴──────────────┐
    │                             │
┌───▼────┐                   ┌────▼───┐
│  ECS   │                   │  ECS   │
│ Fargate│                   │ Fargate│
│  Task  │                   │  Task  │
│(Private│                   │(Private│
│ Subnet)│                   │ Subnet)│
└────┬───┘                   └────┬───┘
     │                            │
     └────────┬──────────────────┘
              │
        ┌─────▼──────┐
        │    NAT     │  ← Static IP (Elastic IP)
        │  Gateway   │     (outbound traffic)
        └────────────┘
```

**Key Components:**
- **VPC**: Isolated network (10.0.0.0/16)
- **Public Subnets**: Host ALB and NAT Gateway
- **Private Subnets**: Host ECS Fargate tasks (enhanced security)
- **Application Load Balancer (ALB)**: Provides stable DNS endpoint for Salesforce callback
- **ECR**: Stores your Docker images securely
- **Secrets Manager**: Securely stores Salesforce credentials
- **CloudWatch Logs**: Container logs (7-day retention)
- **ECS Fargate**: Serverless container execution (no EC2 management)

---

## Prerequisites

### 1. AWS Account Setup
- Active AWS account
- AWS CLI installed and configured: `aws configure`
- Sufficient permissions to create VPC, ECS, ECR, Secrets Manager resources

### 2. Terraform Setup
```bash
# Install Terraform (macOS)
brew install terraform

# Verify installation
terraform --version
```

### 3. Docker Setup
- Docker Desktop installed and running
- Image built locally: `docker build -t sf-oauth-demo .`

### 4. Salesforce Connected App
- Consumer Key and Consumer Secret ready
- **Important**: You'll need to update the callback URL after initial deployment

---

## Step-by-Step Deployment

### Step 1: Configure AWS Credentials

```bash
# Use your existing AWS profile
export AWS_PROFILE=gforce
export AWS_REGION=eu-central-1

# Verify your identity
aws sts get-caller-identity --profile gforce
```

### Step 2: Create Terraform Variables File

```bash
cd terraform

# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Initial `terraform.tfvars` (before first deployment):**
```hcl
aws_region    = "eu-central-1"
project_name  = "sf-oauth-demo"
environment   = "dev"

# Salesforce credentials
sf_client_id     = "YOUR_SALESFORCE_CONSUMER_KEY"
sf_client_secret = "YOUR_SALESFORCE_CONSUMER_SECRET"
sf_callback_url  = "http://PLACEHOLDER/oauth/callback"  # Update after deployment
sf_login_url     = "https://login.salesforce.com"

# Placeholder - will update after ECR creation
container_image = "PLACEHOLDER"

# Generate a secure random string (32+ characters)
session_secret = "$(openssl rand -base64 32)"
```

### Step 3: Create ECR Repository and Push Docker Image

```bash
# Initialize Terraform
terraform init

# Create only the ECR repository first
terraform apply -target=aws_ecr_repository.app

# Get the ECR repository URL from output
export ECR_URL=$(terraform output -raw ecr_repository_url)
echo "ECR URL: $ECR_URL"

# Authenticate Docker with ECR
aws ecr get-login-password --region eu-central-1 --profile gforce | \
  docker login --username AWS --password-stdin $ECR_URL

# Tag your Docker image
docker tag sf-oauth-demo:latest $ECR_URL:latest

# Push to ECR
docker push $ECR_URL:latest
```

**Update `terraform.tfvars` with the ECR URL:**
```hcl
container_image = "123456789012.dkr.ecr.eu-central-1.amazonaws.com/sf-oauth-demo:latest"
```

### Step 4: Deploy Infrastructure (First Pass)

```bash
# Review the deployment plan
terraform plan

# Deploy all infrastructure
terraform apply
```

This will create:
- ✅ VPC with public/private subnets
- ✅ Application Load Balancer (ALB)
- ✅ ECS Cluster and Service
- ✅ Secrets Manager with your credentials
- ✅ IAM roles with least-privilege access
- ✅ CloudWatch log group

**Wait for deployment to complete (~5-10 minutes)**

### Step 5: Get the ALB DNS Name (Your Static Endpoint)

```bash
# Get ALB DNS name
terraform output alb_dns_name

# Example output:
# sf-oauth-demo-alb-1234567890.eu-central-1.elb.amazonaws.com
```

### Step 6: Update Salesforce Connected App Callback URL

1. Go to Salesforce Setup → App Manager → Your Connected App → Edit
2. Update **Callback URL** to:
   ```
   http://YOUR-ALB-DNS-NAME/oauth/callback
   ```
   Example:
   ```
   http://sf-oauth-demo-alb-1234567890.eu-central-1.elb.amazonaws.com/oauth/callback
   ```
3. Save the changes

### Step 7: Update Terraform Variables and Redeploy

**Update `terraform.tfvars` with correct callback URL:**
```hcl
sf_callback_url = "http://sf-oauth-demo-alb-1234567890.eu-central-1.elb.amazonaws.com/oauth/callback"
```

```bash
# Apply changes (updates Secrets Manager)
terraform apply
```

### Step 8: Verify Deployment

```bash
# Get the application URL
terraform output alb_url

# Check ECS service status
aws ecs describe-services \
  --cluster sf-oauth-demo-cluster \
  --services sf-oauth-demo-service \
  --region eu-central-1 \
  --profile gforce

# Check container logs
aws logs tail /ecs/sf-oauth-demo --follow --region eu-central-1 --profile gforce
```

**Test the application:**
1. Open browser to ALB URL (from `terraform output alb_url`)
2. You should see the login page
3. Click "Login with Salesforce"
4. Complete OAuth flow
5. Create a test lead

---

## Static IP for Salesforce Callback

### Why You Need a Static Endpoint

Salesforce requires a **stable callback URL** configured in your Connected App. AWS provides two options:

#### Option 1: ALB DNS Name (Current Implementation) ✅
- **Pros**: 
  - Free (included with ALB)
  - Automatically provisioned
  - Stable for the lifetime of the ALB
- **Cons**:
  - Long DNS name
  - HTTP only (in this demo)

**The ALB DNS name never changes** unless you destroy and recreate the ALB. This is perfect for demos and development.

#### Option 2: Elastic IP with Network Load Balancer (Alternative)

If you need a true static IP:

```hcl
# Add to alb.tf
resource "aws_eip" "nlb" {
  domain = "vpc"
  
  tags = {
    Name = "${var.project_name}-nlb-eip"
  }
}

resource "aws_lb" "network" {
  name               = "${var.project_name}-nlb"
  load_balancer_type = "network"
  
  subnet_mapping {
    subnet_id     = aws_subnet.public_1.id
    allocation_id = aws_eip.nlb.id
  }
}
```

**Note**: For this demo, the ALB DNS name is sufficient and cost-effective.

---

## Security Best Practices

### ✅ Implemented Security Features

1. **Private Subnets for ECS Tasks**
   - Containers run in private subnets (no direct internet access)
   - All outbound traffic routed through NAT Gateway

2. **Secrets Manager for Credentials**
   - Salesforce credentials never in code or environment variables
   - Automatic encryption at rest (AWS KMS)
   - Fine-grained IAM access control

3. **Least Privilege IAM Roles**
   - **ECS Task Execution Role**: Only for pulling images and logs
   - **ECS Task Role**: Only for reading specific secrets
   - No wildcard permissions

4. **Security Groups (Network Firewalls)**
   - ALB: Only ports 80/443 from internet
   - ECS Tasks: Only port 3000 from ALB
   - No SSH access (Fargate is managed)

5. **Container Image Scanning**
   - ECR scans on every push
   - Identifies vulnerabilities before deployment

6. **CloudWatch Logs**
   - All container output logged
   - 7-day retention (compliance)
   - No sensitive data logged

### 🔒 Additional Security Recommendations

For production deployments, consider:

1. **HTTPS/TLS Encryption**
   ```hcl
   # Add to alb.tf
   resource "aws_lb_listener" "https" {
     load_balancer_arn = aws_lb.main.arn
     port              = "443"
     protocol          = "HTTPS"
     certificate_arn   = aws_acm_certificate.app.arn
     
     default_action {
       type             = "forward"
       target_group_arn = aws_lb_target_group.app.arn
     }
   }
   ```

2. **Custom Domain with Route 53**
   - Example: `oauth.yourdomain.com`
   - Better than ALB DNS name

3. **VPC Flow Logs**
   - Monitor all network traffic

4. **AWS WAF**
   - Protect against web exploits
   - Rate limiting

5. **Secrets Rotation**
   - Automatic credential rotation every 90 days

See [docs/IAM_SECURITY.md](./IAM_SECURITY.md) for detailed IAM policy explanations.

---

## Cost Management

### 💰 Estimated Monthly Costs (eu-central-1)

For a **demo/development** deployment running **8 hours/day, 20 days/month**:

| Service | Cost | Notes |
|---------|------|-------|
| ECS Fargate (0.25 vCPU, 0.5 GB) | ~$6 | 160 hours/month |
| Application Load Balancer | ~$18 | Fixed cost |
| NAT Gateway | ~$5 | Data transfer + hourly |
| Secrets Manager | ~$0.40 | Per secret/month |
| CloudWatch Logs (< 5 GB) | < $1 | 7-day retention |
| ECR Storage (< 1 GB) | < $0.10 | Image storage |
| **TOTAL** | **~$30/month** | 8 hrs/day usage |

**Running 24/7**: ~$70/month

### 💡 Cost Optimization Tips

1. **Stop ECS Service When Not in Use**
   ```bash
   # Set desired count to 0 (stops all tasks)
   aws ecs update-service \
     --cluster sf-oauth-demo-cluster \
     --service sf-oauth-demo-service \
     --desired-count 0 \
     --region eu-central-1 \
     --profile gforce
   
   # Restart when needed
   aws ecs update-service \
     --cluster sf-oauth-demo-cluster \
     --service sf-oauth-demo-service \
     --desired-count 1 \
     --region eu-central-1 \
     --profile gforce
   ```

2. **Use AWS Budgets**
   - Set a budget alert at $40/month
   - Get notified before overspending

3. **Complete Teardown After Demo**
   - See [Teardown Instructions](#teardown-instructions) below

---

## Teardown Instructions

### 🗑️ Complete Infrastructure Cleanup

**IMPORTANT**: This destroys ALL resources and cannot be undone!

```bash
cd terraform

# Preview what will be destroyed
terraform plan -destroy

# Destroy all infrastructure
terraform destroy

# Confirm when prompted by typing: yes
```

**Manual Cleanup (if needed):**

1. **Empty ECR Repository** (if Terraform fails):
   ```bash
   aws ecr batch-delete-image \
     --repository-name sf-oauth-demo \
     --image-ids imageTag=latest \
     --region eu-central-1 \
     --profile gforce
   ```

2. **Delete CloudWatch Log Groups** (if needed):
   ```bash
   aws logs delete-log-group \
     --log-group-name /ecs/sf-oauth-demo \
     --region eu-central-1 \
     --profile gforce
   ```

3. **Verify Deletion**:
   ```bash
   # Check for remaining resources
   aws resourcegroupstaggingapi get-resources \
     --tag-filters Key=Environment,Values=dev \
     --region eu-central-1 \
     --profile gforce
   ```

### Terraform State Cleanup

```bash
# Remove local state files
rm -rf .terraform/
rm terraform.tfstate*

# If using remote state (S3), delete the bucket
```

**Cost After Teardown**: $0 (all resources deleted)

---

## Troubleshooting

### ECS Tasks Failing to Start

**Check logs:**
```bash
aws logs tail /ecs/sf-oauth-demo --follow --region eu-central-1 --profile gforce
```

**Common issues:**
1. **Image pull failed**: Check ECR authentication
2. **Health check failing**: Verify `/health` endpoint returns 200
3. **Secrets access denied**: Check IAM role permissions

### Application Not Accessible

**Verify ALB health:**
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn) \
  --region eu-central-1 \
  --profile gforce
```

**Expected output**: `State: healthy`

**If unhealthy:**
- Check security group rules
- Verify container is running on port 3000
- Check application logs

### OAuth Callback Fails

**Symptoms**: 
- "redirect_uri_mismatch" error from Salesforce

**Solution:**
1. Verify Salesforce callback URL matches exactly:
   ```bash
   terraform output alb_url
   # URL should be: http://YOUR-ALB-DNS/oauth/callback
   ```
2. Update in Salesforce Connected App
3. Update `terraform.tfvars` and re-apply

### High AWS Costs

**Check current spend:**
```bash
aws ce get-cost-and-usage \
  --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --profile gforce
```

**Stop all tasks to reduce costs:**
```bash
aws ecs update-service \
  --cluster sf-oauth-demo-cluster \
  --service sf-oauth-demo-service \
  --desired-count 0 \
  --region eu-central-1 \
  --profile gforce
```

---

## Next Steps

- ✅ **Production Deployment**: Add HTTPS, custom domain, WAF
- ✅ **CI/CD Pipeline**: Automate deployments with GitHub Actions
- ✅ **Monitoring**: Set up CloudWatch alarms for errors
- ✅ **Backup**: Version your Terraform state in S3

For detailed IAM security policies, see [IAM_SECURITY.md](./IAM_SECURITY.md)

For questions or issues, check the [main README](../README.md) or application logs.
