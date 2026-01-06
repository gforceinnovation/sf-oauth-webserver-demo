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
- **[Docker Guide](docs/DOCKER.md)** - How to build and run the application in Docker
- **[AWS Deployment Guide](docs/AWS_DEPLOYMENT.md)** - Deploy to AWS ECS with Terraform (includes static IP, IAM security, and cost management)
- **[IAM Security Guide](docs/IAM_SECURITY.md)** - Detailed IAM roles and security best practices
- **[Quick Start](#-quick-start)** - Get started in 5 minutes (see below)
- **[API Reference](#-api-endpoints)** - All available endpoints
- **[Architecture](#️-architecture)** - How the modules work together

## 📁 Project Structure

```
salesforce-oauth-demo/
├── docs/
│   ├── AUTH_SETUP.md         # 📖 Detailed auth setup & flow explanation
│   ├── DOCKER.md             # 🐳 Docker build & run guide
│   ├── AWS_DEPLOYMENT.md     # ☁️ AWS ECS deployment guide
│   └── IAM_SECURITY.md       # 🔒 IAM roles & security practices
├── scripts/
│   └── ecr-helper.sh         # 🛠️ ECR image management helper
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

## 🐳 Running with Docker

**📖 For complete Docker documentation, see [docs/DOCKER.md](docs/DOCKER.md)**

### Quick Docker Start

Build the image:
```bash
docker build -t sf-oauth-demo .
```

Run with your .env file (easiest):
```bash
docker run -p 3000:3000 --env-file .env sf-oauth-demo
```

Or pass environment variables directly:
```bash
docker run -p 3000:3000 \
  -e SF_CLIENT_ID="your_client_id" \
  -e SF_CLIENT_SECRET="your_client_secret" \
  -e SF_CALLBACK_URL="http://localhost:3000/oauth/callback" \
  -e SF_LOGIN_URL="https://login.salesforce.com" \
  -e SESSION_SECRET="your_session_secret" \
  sf-oauth-demo
```

Run in background (detached mode):
```bash
docker run -d -p 3000:3000 --env-file .env --name sf-oauth sf-oauth-demo
```

View logs:
```bash
docker logs -f sf-oauth
```

Visit **http://localhost:3000** to test!

**See [docs/DOCKER.md](docs/DOCKER.md) for:**
- Container management commands
- Health checks
- Troubleshooting
- Production deployment
- Docker Compose setup
  -e SF_CLIENT_ID=your_consumer_key \
  -e SF_CLIENT_SECRET=your_consumer_secret \
  -e SF_CALLBACK_URL=http://localhost:3000/oauth/callback \
  -e SF_LOGIN_URL=https://login.salesforce.com \
  -e SESSION_SECRET=your_session_secret \
  sf-oauth-demo
```

Test at `http://localhost:3000`

## ☁️ AWS Deployment

**📖 For complete AWS deployment guide, see [docs/AWS_DEPLOYMENT.md](docs/AWS_DEPLOYMENT.md)**

The application can be deployed to AWS ECS Fargate using the included Terraform configuration. This provides:
- ✅ Stable ALB DNS name for Salesforce callback URL
- ✅ Secure secrets management (AWS Secrets Manager)
- ✅ Private subnets with proper IAM security
- ✅ Auto-scaling and high availability
- ✅ Easy teardown after demo (save costs)

### Quick AWS Deployment

**Prerequisites:**
- AWS CLI configured with profile `gforce` and region `eu-central-1`
- Terraform installed
- Docker image built

**1. Use the ECR Helper Script:**
```bash
# Full deployment: build, tag, push to ECR
./scripts/ecr-helper.sh deploy

# This will output your ECR image URI
```

**2. Configure Terraform:**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Salesforce credentials and ECR image URI
```

**3. Deploy Infrastructure:**
```bash
terraform init
terraform plan
terraform apply
```

**4. Get your ALB URL and update Salesforce:**
```bash
terraform output alb_url
# Update your Salesforce Connected App callback URL with this DNS name
```

**See [docs/AWS_DEPLOYMENT.md](docs/AWS_DEPLOYMENT.md) for:**
- Step-by-step deployment walkthrough
- Static IP configuration
- IAM security setup (see also [docs/IAM_SECURITY.md](docs/IAM_SECURITY.md))
- Secrets injection to containers
- Cost estimates (~$30/month for demo usage)
- Complete teardown instructions
- Troubleshooting guide

## 🧪 Testing Locally

1. Start the server: `npm start`
2. Open `http://localhost:3000`
3. Click "Login with Salesforce"
4. Authorize the application
5. Fill in the Lead form and create a test lead
6. Verify the lead in Salesforce

## 🏗️ Architecture

### AWS Deployment Architecture
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

For detailed architecture and security, see [docs/AWS_DEPLOYMENT.md](docs/AWS_DEPLOYMENT.md) and [docs/IAM_SECURITY.md](docs/IAM_SECURITY.md).

## 💰 AWS Cost Optimization

**Estimated monthly cost**: ~$30 for demo usage (8 hrs/day, 20 days/month)

**To minimize costs:**
- Stop the ECS service when not demoing: 
  ```bash
  aws ecs update-service --cluster sf-oauth-demo-cluster \
    --service sf-oauth-demo-service --desired-count 0 \
    --region eu-central-1 --profile gforce
  ```
- Destroy infrastructure when not needed:
  ```bash
  cd terraform
  terraform destroy
  ```

See [docs/AWS_DEPLOYMENT.md](docs/AWS_DEPLOYMENT.md) for detailed cost breakdown and optimization tips.

## 🔒 Security Best Practices

✅ **Implemented:**
- Credentials stored in AWS Secrets Manager
- Non-root container user
- Private subnets for application
- Security groups with minimal required access
- HTTPS-ready (can add ACM certificate)
- Session secrets not hardcoded
- Environment-based configuration
- Least-privilege IAM roles

See [docs/IAM_SECURITY.md](docs/IAM_SECURITY.md) for detailed IAM security policies and best practices.

## 🛠️ Troubleshooting

### OAuth Error: "redirect_uri_mismatch"
- Check callback URL in `.env` matches Salesforce Connected App
- Verify protocol (http vs https)
- Check for trailing slashes

### ECS Task Fails to Start
```bash
# Check logs
aws logs tail /ecs/sf-oauth-demo --follow --region eu-central-1 --profile gforce

# Check task status
aws ecs describe-tasks --cluster sf-oauth-demo-cluster \
  --tasks $(aws ecs list-tasks --cluster sf-oauth-demo-cluster \
  --service-name sf-oauth-demo-service --query 'taskArns[0]' --output text) \
  --region eu-central-1 --profile gforce
```

For more troubleshooting, see [docs/AWS_DEPLOYMENT.md](docs/AWS_DEPLOYMENT.md#troubleshooting).

## 🧹 Cleanup

To completely remove all AWS resources:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This will delete all resources and stop billing.

See [docs/AWS_DEPLOYMENT.md](docs/AWS_DEPLOYMENT.md#teardown-instructions) for detailed cleanup steps.

---

## 📚 Additional Resources

### Documentation in This Repository
- **[Authentication Setup Guide](docs/AUTH_SETUP.md)** - Complete OAuth 2.0 setup with detailed Web Server Flow + PKCE explanation
- **[Docker Guide](docs/DOCKER.md)** - Build and run the application in Docker containers
- **[AWS Deployment Guide](docs/AWS_DEPLOYMENT.md)** - Deploy to AWS ECS with Terraform (static IP, secrets, teardown)
- **[IAM Security Guide](docs/IAM_SECURITY.md)** - Detailed IAM roles, policies, and security best practices

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
