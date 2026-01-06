# IAM Security Guide

This document explains the IAM roles, policies, and security best practices for the Salesforce OAuth Demo deployment on AWS ECS.

## Table of Contents
- [Overview](#overview)
- [IAM Roles Explained](#iam-roles-explained)
- [Policy Breakdown](#policy-breakdown)
- [Security Principles](#security-principles)
- [Verification Steps](#verification-steps)
- [Production Hardening](#production-hardening)

---

## Overview

The application uses **two separate IAM roles** following the **principle of least privilege**:

```
┌─────────────────────────────────────────────────┐
│           ECS Task Definition                    │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │    Task Execution Role                   │  │
│  │    (Infrastructure operations)           │  │
│  │    • Pull Docker images from ECR         │  │
│  │    • Write logs to CloudWatch            │  │
│  │    • Read secrets during startup         │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │    Task Role                             │  │
│  │    (Application runtime operations)      │  │
│  │    • Access Secrets Manager at runtime   │  │
│  │    • Future: S3, DynamoDB, etc.          │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

## IAM Roles Explained

### 1. ECS Task Execution Role

**Purpose**: Used by **ECS (the platform)** to set up your container

**When it's used**:
- Pulling Docker image from ECR
- Starting the container
- Sending container logs to CloudWatch
- Injecting secrets as environment variables (if configured)

**Terraform Resource**: `aws_iam_role.ecs_task_execution`

**Trust Policy** (Who can assume this role):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```
☑️ **Only the ECS service can assume this role**

---

### 2. ECS Task Role

**Purpose**: Used by **your application code** running inside the container

**When it's used**:
- When your Node.js app calls AWS SDK
- Reading secrets from Secrets Manager at runtime
- Future: Accessing S3 buckets, DynamoDB tables, etc.

**Terraform Resource**: `aws_iam_role.ecs_task`

**Trust Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

---

## Policy Breakdown

### Task Execution Role Policies

#### A. AmazonECSTaskExecutionRolePolicy (AWS Managed)

**What it allows**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

**Breakdown**:
- ✅ `ecr:GetAuthorizationToken`: Authenticate to ECR
- ✅ `ecr:BatchGetImage`: Download Docker image layers
- ✅ `logs:PutLogEvents`: Write container stdout/stderr to CloudWatch

#### B. Custom Secrets Access Policy

**Terraform Resource**: `aws_iam_role_policy.secrets_access`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:sf-oauth-demo-sf-credentials-AbCdEf"
      ]
    }
  ]
}
```

**Security Features**:
- ✅ **Specific secret ARN** (not wildcard `*`)
- ✅ **Read-only** (no `PutSecretValue`, `DeleteSecret`)
- ✅ **Single action** (`GetSecretValue` only)

**Why this matters**: Even if your container is compromised, attackers can't:
- Modify the secret
- Delete the secret
- Access other secrets in your account

---

### Task Role Policies

#### Custom Secrets Access Policy (Runtime)

**Terraform Resource**: `aws_iam_role_policy.app_secrets_access`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:sf-oauth-demo-sf-credentials-AbCdEf"
      ]
    }
  ]
}
```

**Note**: Currently identical to execution role policy. This separation allows:
- Different permissions in the future
- Different resources (e.g., app might need S3, execution doesn't)
- Clear separation of concerns

---

## Security Principles

### 1. Principle of Least Privilege ✅

**What we implemented**:
- Each role has **only** the permissions it needs
- No wildcard resources (`Resource: "*"`) except where required by AWS
- No wildcard actions (`Action: "*"`)

**Example**: The application can read ONE specific secret, not all secrets

### 2. Defense in Depth ✅

**Multiple layers of security**:

| Layer | Protection |
|-------|------------|
| Network | Security groups restrict traffic to/from containers |
| Compute | ECS tasks run in private subnets (no internet access) |
| Data | Secrets encrypted at rest (AWS KMS) |
| Identity | IAM roles with minimal permissions |
| Logging | CloudWatch logs all access attempts |

### 3. Separation of Duties ✅

**Two distinct roles**:
- **Platform (Execution Role)**: ECS infrastructure operations
- **Application (Task Role)**: Your code's AWS API calls

**Why this matters**: If an attacker compromises your application code, they can't:
- Pull different Docker images
- Modify log groups
- Escalate privileges

### 4. Encryption in Transit and at Rest ✅

**Secrets Manager**:
- Encrypted at rest using AWS KMS
- Encrypted in transit over TLS
- Automatic key rotation (optional)

**ECR Images**:
- Encrypted at rest by default
- Scanned for vulnerabilities

---

## Verification Steps

### Check Current IAM Roles

```bash
# List roles created by Terraform
aws iam list-roles | grep sf-oauth-demo

# Get execution role details
aws iam get-role --role-name sf-oauth-demo-ecs-task-execution-role

# Get task role details
aws iam get-role --role-name sf-oauth-demo-ecs-task-role
```

### Verify Attached Policies

```bash
# Execution role policies
aws iam list-attached-role-policies \
  --role-name sf-oauth-demo-ecs-task-execution-role

aws iam list-role-policies \
  --role-name sf-oauth-demo-ecs-task-execution-role

# Task role policies
aws iam list-role-policies \
  --role-name sf-oauth-demo-ecs-task-role
```

### Test Secrets Access

```bash
# Verify the secret exists and is accessible
aws secretsmanager get-secret-value \
  --secret-id sf-oauth-demo-sf-credentials \
  --region us-east-1
```

### Check CloudWatch Logs Access

```bash
# Verify log group exists
aws logs describe-log-groups \
  --log-group-name-prefix /ecs/sf-oauth-demo \
  --region us-east-1

# Check recent logs
aws logs tail /ecs/sf-oauth-demo --follow --region us-east-1
```

---

## Production Hardening

### 1. Enable IAM Access Analyzer

**Detects overly permissive policies**:

```bash
aws accessanalyzer create-analyzer \
  --analyzer-name sf-oauth-demo-analyzer \
  --type ACCOUNT \
  --region us-east-1
```

**What it checks**:
- Resources shared outside your account
- Unused permissions (after 90 days)
- External access to secrets

### 2. Add Conditions to Policies

**Restrict access to specific VPCs**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:*:*:secret:sf-oauth-demo-*",
      "Condition": {
        "StringEquals": {
          "aws:SourceVpc": "vpc-xxxxx"
        }
      }
    }
  ]
}
```

### 3. Enable CloudTrail Logging

**Audit all IAM actions**:

```hcl
# Add to terraform/main.tf
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}
```

**What you can audit**:
- Who assumed which role?
- Which secrets were accessed?
- When were permissions changed?

### 4. Secrets Rotation

**Automatic rotation every 90 days**:

```hcl
# Add to terraform/secrets.tf
resource "aws_secretsmanager_secret_rotation" "sf_credentials" {
  secret_id           = aws_secretsmanager_secret.sf_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 90
  }
}
```

### 5. Resource-Based Policies

**Prevent deletion of critical secrets**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": [
        "secretsmanager:DeleteSecret",
        "secretsmanager:PutSecretValue"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:userid": "AIDAI23ABC123EXAMPLE"
        }
      }
    }
  ]
}
```

### 6. VPC Endpoints (No Internet for AWS API Calls)

**Add VPC endpoints for Secrets Manager**:

```hcl
# Add to terraform/vpc.tf
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  
  private_dns_enabled = true
}
```

**Benefits**:
- Secrets Manager traffic never leaves AWS network
- Reduced NAT Gateway costs
- Better security posture

---

## Common Mistakes to Avoid

### ❌ Using Wildcard Resources

**Bad**:
```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:GetSecretValue",
  "Resource": "*"
}
```

**Good**:
```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:GetSecretValue",
  "Resource": "arn:aws:secretsmanager:us-east-1:123456:secret:sf-oauth-demo-*"
}
```

### ❌ Overly Broad Actions

**Bad**:
```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:*",
  "Resource": "arn:aws:secretsmanager:*:*:secret:sf-oauth-demo-*"
}
```

**Good**:
```json
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": "arn:aws:secretsmanager:*:*:secret:sf-oauth-demo-*"
}
```

### ❌ Not Using Conditions

**Consider adding conditions for**:
- Source VPC
- Source IP ranges
- Time-based restrictions
- MFA requirements (for sensitive operations)

### ❌ Hardcoding Credentials

**Never do this**:
```javascript
// BAD - credentials in code
const SF_CLIENT_SECRET = "hardcoded_secret_here";
```

**Always use Secrets Manager or environment variables from secure sources**

---

## Monitoring and Alerts

### Set Up CloudWatch Alarms

**Alert on unauthorized access attempts**:

```hcl
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "${var.project_name}-unauthorized-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "AWS/IAM"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert on multiple unauthorized API calls"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
```

### Review IAM Access Patterns

```bash
# Get IAM credential report
aws iam generate-credential-report
aws iam get-credential-report --output text | base64 -d > iam-report.csv

# Review unused roles
aws iam get-role --role-name sf-oauth-demo-ecs-task-role
```

---

## Summary

### ✅ What's Secure

- Separate execution and task roles
- Least-privilege policies (specific ARNs)
- No wildcards where avoidable
- Encrypted secrets at rest and in transit
- Private subnets for containers
- Security groups restrict network access
- CloudWatch logging enabled

### 🔒 Production Additions

- [ ] VPC Endpoints (eliminate internet for AWS APIs)
- [ ] Secrets rotation (90-day automatic)
- [ ] CloudTrail auditing (who did what, when)
- [ ] IAM Access Analyzer (detect overly permissive policies)
- [ ] Resource-based policies (prevent accidental deletion)
- [ ] Condition-based restrictions (VPC, IP, MFA)

### 📚 Further Reading

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [ECS Task IAM Roles](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)
- [AWS Secrets Manager Security](https://docs.aws.amazon.com/secretsmanager/latest/userguide/security.html)

---

**Questions or concerns?** Review the [AWS Deployment Guide](./AWS_DEPLOYMENT.md) or check CloudWatch logs for issues.
