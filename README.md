# Salesforce OAuth Demo with AWS ECS Deployment

A complete demonstration of Salesforce Web Server OAuth flow with PKCE (Proof Key for Code Exchange) - a Node.js application that showcases secure authentication with Salesforce and can be deployed on AWS ECS Fargate using Terraform.

## 🎯 Features

- ✅ Salesforce OAuth 2.0 Web Server Flow with PKCE
- ✅ Create Leads in Salesforce via web form
- ✅ Clean modular architecture
- ✅ Secure session-based authentication
- ✅ Containerized Node.js application
- ✅ AWS ECS Fargate deployment (Free Tier eligible)
- ✅ Complete Terraform infrastructure
- ✅ Comprehensive documentation

## 📚 Documentation

- **[Authentication Setup Guide](docs/AUTH_SETUP.md)** - Complete guide to setting up Salesforce OAuth with detailed Web Server Flow + PKCE explanation
- **[Quick Start](#-quick-start)** - Get started in 5 minutes (see below)
- **[API Reference](#-api-endpoints)** - All available endpoints
- **[Architecture](#️-architecture)** - How the modules work together

## 📁 Project Structure

```
salesforce-oauth-demo/
├── docs/
│   └── AUTH_SETUP.md         # 📖 Detailed auth setup & flow explanation
├── src/
│   ├── server.js             # Main Express server
│   ├── auth/
│   │   └── oauth.js          # OAuth flow handlers (PKCE)
│   └── salesforce/
│       └── api.js            # Salesforce API functions
├── public/
│   ├── login.html            # Login page
│   └── app.html              # Lead creation form
├── terraform/                # AWS infrastructure (optional)
├── .env.example              # Environment variables template
├── Dockerfile                # Container configuration
└── README.md                 # This file
```

## 📋 Prerequisites

- Node.js 18+ (for local development)
- Salesforce Developer Account (free)
- Docker (optional, for containerization)
- AWS Account (optional, for deployment)
- Terraform 1.0+ (optional, for infrastructure)

## 🚀 Quick Start

### 1. Setup Salesforce Connected App

**📖 For detailed step-by-step instructions with screenshots and troubleshooting, see [docs/AUTH_SETUP.md](docs/AUTH_SETUP.md)**

**For a deep dive into how OAuth 2.0 Web Server Flow with PKCE works, see the ["How It Works" section](docs/AUTH_SETUP.md#how-it-works) in the auth guide.**

Quick summary:
1. Go to Salesforce Setup → App Manager → New Connected App
2. Enable OAuth Settings
3. Set Callback URL: `http://localhost:3000/oauth/callback`
4. Enable **PKCE** (Proof Key for Code Exchange)
5. Select OAuth Scopes: `full`, `refresh_token`, `api`
6. Copy your Consumer Key and Consumer Secret

### 2. Local Development Setup

```bash
# Install dependencies
npm install

# Create .env file
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
SESSION_SECRET=generate_random_32_char_string
```

Generate a random session secret:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### 3. Start the Development Server

```bash
npm start
```

Visit `http://localhost:3000` and test the OAuth flow!

## 🏗️ Architecture

### OAuth 2.0 Web Server Flow with PKCE

This application implements the secure **OAuth 2.0 Web Server Flow** with **PKCE** (Proof Key for Code Exchange). PKCE adds an extra layer of security by preventing authorization code interception attacks.

**📖 For a detailed explanation of how Web Server Flow with PKCE works, including step-by-step process, security details, and diagrams, see [docs/AUTH_SETUP.md - How It Works](docs/AUTH_SETUP.md#how-it-works)**

#### Simplified Flow

```
┌─────────┐                                           ┌─────────────┐
│  User   │  1. Login Request                        │             │
│ Browser ├──────────────────────────────────────────►│ Salesforce  │
│         │                                           │   OAuth     │
│         │  2. Auth Code (after user approves)      │   Server    │
│         │◄──────────────────────────────────────────┤             │
└────┬────┘                                           └─────────────┘
     │                                                       ▲
     │                                                       │
     │  3. Auth Code                                        │ 4. Token Request
     │                                                       │    + PKCE Verifier
     ▼                                                       │
┌─────────┐                                           ┌─────┴───────┐
│   App   │  5. Access Token                         │ Salesforce  │
│ Server  │◄──────────────────────────────────────────┤   OAuth     │
│         │                                           │   Server    │
│         │  6. API Calls (Create Lead, etc.)        │             │
│         ├──────────────────────────────────────────►│             │
└─────────┘                                           └─────────────┘
```

**Key Security Features:**
- 🔐 **PKCE Code Verifier** - Random secret generated per authentication request
- 🔐 **Code Challenge** - SHA256 hash sent to Salesforce (verifier stays on server)
- 🔐 **Verification** - Salesforce validates verifier matches challenge during token exchange
- 🔐 **Client Secret** - Never exposed to browser, only used server-side

### Code Modules

**`src/auth/oauth.js`** - OAuth authentication logic
- `initiateOAuthFlow()` - Starts OAuth with PKCE (generates verifier and challenge)
- `handleOAuthCallback()` - Exchanges authorization code + verifier for access token
- `requireAuth()` - Middleware to protect routes requiring authentication
- `logout()` - Destroys session and clears tokens

**`src/salesforce/api.js`** - Salesforce API functions
- `getUserInfo()` - Fetches current user details from Salesforce
- `createLead()` - Creates a new lead in Salesforce CRM

**`src/server.js`** - Main application server
- Express app configuration
- Route definitions
- API endpoint handlers

## 📝 API Endpoints

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/` | Login page | No |
| GET | `/auth/salesforce` | Initiate OAuth flow with PKCE | No |
| GET | `/oauth/callback` | OAuth callback handler (receives auth code) | No |
| GET | `/app` | Lead creation form | Yes |
| GET | `/api/user` | Get current user info | Yes |
| POST | `/api/lead` | Create a new lead in Salesforce | Yes |
| POST | `/api/logout` | Logout and destroy session | Yes |
| GET | `/health` | Health check endpoint | No |

## 🔐 Security Features

- **PKCE (Proof Key for Code Exchange)** - Prevents authorization code interception attacks ([Learn more](docs/AUTH_SETUP.md#why-web-server-flow-with-pkce-is-secure))
- **Session-based authentication** - Secure server-side token storage (not in browser)
- **Environment variables** - Sensitive data (client secret) not in code
- **Short-lived authorization codes** - Valid for only 15 minutes
- **HTTPS support** - All production traffic encrypted (recommended)
- **Client secret protection** - Never exposed to client

## 🧪 Testing Locally

1. Start the server: `npm start`
2. Open `http://localhost:3000`
3. Click "Login with Salesforce"
4. Authorize the application
5. Fill in the Lead form and create a test lead
6. Verify the lead in Salesforce

## 🐳 Docker Build and Test

Build the Docker image:
```bash
docker build -t sf-oauth-demo .
```

Run the container locally:
```bash
docker run -p 3000:3000 \
  -e SF_CLIENT_ID="your_client_id" \
  -e SF_CLIENT_SECRET="your_client_secret" \
  -e SF_CALLBACK_URL="http://localhost:3000/oauth/callback" \
  -e SF_LOGIN_URL="https://login.salesforce.com" \
  -e SESSION_SECRET="your_session_secret" \
  sf-oauth-demo
```
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

---

## 📚 Additional Resources

### Documentation in This Repository
- **[Authentication Setup Guide](docs/AUTH_SETUP.md)** - Complete OAuth 2.0 setup with detailed Web Server Flow + PKCE explanation
  - Salesforce Connected App configuration
  - Step-by-step OAuth flow breakdown
  - PKCE security explanation
  - Troubleshooting guide

### External Resources
- [Salesforce OAuth 2.0 Web Server Flow Documentation](https://help.salesforce.com/s/articleView?id=sf.remoteaccess_oauth_web_server_flow.htm)
- [OAuth 2.0 Specification](https://oauth.net/2/)
- [PKCE Extension RFC 7636](https://datatracker.ietf.org/doc/html/rfc7636)
- [Salesforce REST API Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/)

### Learning Path
1. **Start Here:** [Quick Start](#-quick-start) to get the app running
2. **Deep Dive:** [OAuth Flow Explanation](docs/AUTH_SETUP.md#how-it-works) to understand the security
3. **Customize:** Review the modular code structure and extend as needed
4. **Deploy:** Use Terraform to deploy to AWS (optional)

---

## 📝 License

This is a demo project for educational purposes.

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📞 Support

For issues with:
- **OAuth Flow & PKCE**: See [docs/AUTH_SETUP.md](docs/AUTH_SETUP.md) troubleshooting section
- **Salesforce Setup**: Check the [Authentication Setup Guide](docs/AUTH_SETUP.md)
- **AWS Deployment**: Review CloudWatch logs and AWS documentation
- **Terraform**: Run `terraform plan` to debug configuration

---

**Happy Coding! 🚀**

Built with ❤️ to demonstrate secure OAuth 2.0 Web Server Flow with PKCE
