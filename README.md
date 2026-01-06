# Salesforce OAuth Demo with AWS ECS Deployment

A complete demonstration of Salesforce Web Server OAuth flow with a Node.js application deployed on AWS ECS Fargate using Terraform infrastructure as code.

## 🎯 Features

- ✅ Salesforce OAuth 2.0 Web Server Flow
- ✅ Create Leads in Salesforce via web form
- ✅ Containerized Node.js application
- ✅ AWS ECS Fargate deployment (Free Tier eligible)
- ✅ AWS Secrets Manager for credential storage
- ✅ Application Load Balancer with health checks
- ✅ Complete Terraform infrastructure
- ✅ DevOps best practices

## 📋 Prerequisites

- Node.js 18+ (for local development)
- Docker (for containerization)
- AWS CLI configured with credentials
- Terraform 1.0+
- Salesforce Developer Account
- AWS Account (Free Tier eligible)

## 🚀 Quick Start

### 1. Setup Salesforce Connected App

1. Log in to your Salesforce account
2. Go to **Setup** → **App Manager** → **New Connected App**
3. Fill in the basic information:
   - **Connected App Name**: SF OAuth Demo
   - **API Name**: sf_oauth_demo
   - **Contact Email**: your-email@example.com
4. Enable OAuth Settings:
   - ✅ **Enable OAuth Settings**
   - **Callback URL**: `http://localhost:3000/oauth/callback` (for local testing)
   - **Selected OAuth Scopes**:
     - Full access (full)
     - Perform requests at any time (refresh_token, offline_access)
     - Access and manage your data (api)
5. **Save** and wait 2-10 minutes for propagation
6. Copy your **Consumer Key** and **Consumer Secret**

### 2. Local Development Setup

```bash
# Navigate to project directory
cd /Users/gaborbalint.demeter/gforce

# Install dependencies
npm install

# Create .env file from example
cp .env.example .env

# Edit .env with your Salesforce credentials
nano .env
```

Update your `.env` file:
```env
SF_CLIENT_ID=your_consumer_key_from_salesforce
SF_CLIENT_SECRET=your_consumer_secret_from_salesforce
SF_CALLBACK_URL=http://localhost:3000/oauth/callback
SF_LOGIN_URL=https://login.salesforce.com
PORT=3000
SESSION_SECRET=generate_a_random_32_char_string_here
```

Generate a random session secret:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Start the development server:
```bash
npm start
```

Visit `http://localhost:3000` and test the OAuth flow!

### 3. Test Locally

1. Open `http://localhost:3000`
2. Click **Login with Salesforce**
3. Authorize the application
4. Fill in the Lead form and create a test lead
5. Verify the lead in Salesforce

## 🐳 Docker Build and Test

Build the Docker image:
```bash
docker build -t sf-oauth-demo .
```

Run the container locally:
```bash
docker run -p 3000:3000 \
  -e SF_CLIENT_ID=your_consumer_key \
  -e SF_CLIENT_SECRET=your_consumer_secret \
  -e SF_CALLBACK_URL=http://localhost:3000/oauth/callback \
  -e SF_LOGIN_URL=https://login.salesforce.com \
  -e SESSION_SECRET=your_session_secret \
  sf-oauth-demo
```

Test at `http://localhost:3000`

## ☁️ AWS Deployment

### Step 1: Configure AWS CLI

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

### Step 2: Create ECR Repository and Push Image

```bash
# Get your AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1

# Authenticate Docker to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Note: ECR repository will be created by Terraform, but if you want to push first:
# Create ECR repository
aws ecr create-repository --repository-name sf-oauth-demo --region $AWS_REGION

# Build and tag image
docker build -t sf-oauth-demo .
docker tag sf-oauth-demo:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/sf-oauth-demo:latest

# Push to ECR
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/sf-oauth-demo:latest
```

### Step 3: Configure Terraform Variables

```bash
cd terraform

# Copy example tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Update `terraform.tfvars`:
```hcl
aws_region    = "us-east-1"
project_name  = "sf-oauth-demo"
environment   = "dev"

sf_client_id     = "your_salesforce_consumer_key"
sf_client_secret = "your_salesforce_consumer_secret"
sf_callback_url  = "http://TEMP-placeholder/oauth/callback"  # Will update after deployment
sf_login_url     = "https://login.salesforce.com"

container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/sf-oauth-demo:latest"
session_secret  = "your_generated_session_secret"
```

### Step 4: Deploy Infrastructure with Terraform

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply infrastructure (this takes ~5-10 minutes)
terraform apply
```

When prompted, type `yes` to confirm.

**Save the outputs!** You'll need the ALB DNS name:
```
Outputs:

alb_dns_name = "sf-oauth-demo-alb-1234567890.us-east-1.elb.amazonaws.com"
alb_url = "http://sf-oauth-demo-alb-1234567890.us-east-1.elb.amazonaws.com"
```

### Step 5: Update Salesforce Connected App Callback URL

1. Go to Salesforce **Setup** → **App Manager**
2. Find your Connected App → **Edit**
3. Add the new callback URL:
   ```
   http://your-alb-dns-name/oauth/callback
   ```
4. Keep the localhost URL for local testing
5. **Save**

### Step 6: Update Terraform with Correct Callback URL

Edit `terraform/terraform.tfvars`:
```hcl
sf_callback_url = "http://sf-oauth-demo-alb-1234567890.us-east-1.elb.amazonaws.com/oauth/callback"
```

Update the secret in AWS:
```bash
terraform apply
```

### Step 7: Restart ECS Service

```bash
# Force new deployment to pick up updated secrets
aws ecs update-service \
  --cluster sf-oauth-demo-cluster \
  --service sf-oauth-demo-service \
  --force-new-deployment \
  --region us-east-1
```

Wait 2-3 minutes for the new task to start.

### Step 8: Test Your Application

Visit your ALB URL: `http://your-alb-dns-name`

🎉 Your application is now live on AWS!

## 📁 Project Structure

```
gforce/
├── src/
│   └── server.js              # Express server with OAuth logic
├── public/
│   ├── login.html             # Login page
│   └── index.html             # Lead creation form
├── terraform/
│   ├── main.tf                # Provider configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   ├── vpc.tf                 # VPC and networking
│   ├── alb.tf                 # Application Load Balancer
│   ├── ecs.tf                 # ECS cluster, service, tasks
│   ├── secrets.tf             # AWS Secrets Manager
│   └── terraform.tfvars       # Your variable values (gitignored)
├── Dockerfile                 # Container definition
├── .dockerignore
├── package.json
├── .env.example
├── .gitignore
└── README.md
```

## 🏗️ Architecture

```
Internet
    ↓
Application Load Balancer (Public Subnets)
    ↓
ECS Fargate Tasks (Private Subnets)
    ↓
NAT Gateway → Internet (for Salesforce API calls)
    ↓
AWS Secrets Manager (Credentials)
```

## 💰 AWS Cost Optimization

This setup is designed for AWS Free Tier:

- **ECS Fargate**: First 20 GB storage + 10 GB data transfer free
- **ALB**: First 15 LCU and 750 hours free monthly
- **Secrets Manager**: First 30 days free, then ~$0.40/month per secret
- **CloudWatch Logs**: 5 GB ingestion free monthly
- **NAT Gateway**: ~$32/month (NOT free tier) - only significant cost

**To minimize costs:**
- Stop the ECS service when not demoing: 
  ```bash
  aws ecs update-service --cluster sf-oauth-demo-cluster \
    --service sf-oauth-demo-service --desired-count 0
  ```
- Destroy infrastructure when not needed:
  ```bash
  terraform destroy
  ```

## 🔒 Security Best Practices

✅ **Implemented:**
- Credentials stored in AWS Secrets Manager
- Non-root container user
- Private subnets for application
- Security groups with minimal required access
- HTTPS-ready (can add ACM certificate)
- Session secrets not hardcoded
- Environment-based configuration

## 🛠️ Troubleshooting

### OAuth Error: "redirect_uri_mismatch"
- Check callback URL in `.env` matches Salesforce Connected App
- Verify protocol (http vs https)
- Check for trailing slashes

### ECS Task Fails to Start
```bash
# Check logs
aws logs tail /ecs/sf-oauth-demo --follow --region us-east-1

# Check task status
aws ecs describe-tasks --cluster sf-oauth-demo-cluster \
  --tasks $(aws ecs list-tasks --cluster sf-oauth-demo-cluster \
  --service-name sf-oauth-demo-service --query 'taskArns[0]' --output text) \
  --region us-east-1
```

### Can't Access Application
- Wait 2-3 minutes after deployment
- Check ALB target group health:
  ```bash
  aws elbv2 describe-target-health \
    --target-group-arn $(terraform output -raw target_group_arn) \
    --region us-east-1
  ```

### Update Secrets
```bash
cd terraform
# Edit terraform.tfvars
terraform apply

# Force new deployment
aws ecs update-service --cluster sf-oauth-demo-cluster \
  --service sf-oauth-demo-service --force-new-deployment
```

## 📚 API Endpoints

- `GET /` - Main application (redirects to login if not authenticated)
- `GET /auth/salesforce` - Initiates OAuth flow
- `GET /oauth/callback` - OAuth callback handler
- `GET /api/user` - Get current user info
- `POST /api/lead` - Create a new lead in Salesforce
- `POST /api/logout` - Logout and destroy session
- `GET /health` - Health check endpoint

## 🔄 CI/CD Deployment

For continuous deployment, add these steps to your CI/CD pipeline:

```bash
# Build and push new image
docker build -t $ECR_REPO:$VERSION .
docker push $ECR_REPO:$VERSION

# Update task definition with new image
aws ecs register-task-definition --cli-input-json file://task-def.json

# Update service
aws ecs update-service \
  --cluster sf-oauth-demo-cluster \
  --service sf-oauth-demo-service \
  --task-definition sf-oauth-demo:$NEW_VERSION \
  --force-new-deployment
```

## 🧹 Cleanup

To completely remove all AWS resources:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This will delete:
- ECS Service and Cluster
- Load Balancer and Target Groups
- VPC, Subnets, and Networking
- Secrets Manager secret (after 7-day recovery window)
- CloudWatch Log Groups
- IAM Roles and Policies

## 📝 License

This is a demo project for educational purposes.

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📞 Support

For issues with:
- **Salesforce OAuth**: Check Salesforce documentation
- **AWS Services**: Review CloudWatch logs and AWS documentation
- **Terraform**: Run `terraform plan` to debug configuration

---

**Happy Demoing! 🚀**
