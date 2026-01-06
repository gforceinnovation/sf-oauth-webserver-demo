#!/bin/bash

# ECR Helper Script for Salesforce OAuth Demo
# This script helps manage Docker images in AWS ECR

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
AWS_PROFILE="${AWS_PROFILE:-gforce}"
AWS_REGION="${AWS_REGION:-eu-central-1}"
PROJECT_NAME="sf-oauth-demo"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Functions
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        echo "Install it with: brew install awscli"
        exit 1
    fi
    print_success "AWS CLI found"
}

# Check if Docker is running
check_docker() {
    if ! docker info &> /dev/null; then
        print_error "Docker is not running"
        echo "Please start Docker Desktop and try again"
        exit 1
    fi
    print_success "Docker is running"
}

# Get AWS account ID
get_account_id() {
    ACCOUNT_ID=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --query Account --output text 2>/dev/null)
    if [ -z "$ACCOUNT_ID" ]; then
        print_error "Failed to get AWS account ID"
        echo "Run: aws configure --profile $AWS_PROFILE"
        exit 1
    fi
    print_success "AWS Account ID: $ACCOUNT_ID (profile: $AWS_PROFILE)"
}

# Build ECR repository URL
build_ecr_url() {
    ECR_URL="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${PROJECT_NAME}"
    print_info "ECR URL: $ECR_URL"
}

# Authenticate Docker with ECR
ecr_login() {
    print_header "Authenticating with ECR"
    
    aws ecr get-login-password --region "$AWS_REGION" --profile "$AWS_PROFILE" | \
        docker login --username AWS --password-stdin "$ECR_URL" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Docker authenticated with ECR"
    else
        print_error "Failed to authenticate with ECR"
        exit 1
    fi
}

# Create ECR repository if it doesn't exist
create_repository() {
    print_header "Checking ECR Repository"
    
    if aws ecr describe-repositories --repository-names "$PROJECT_NAME" --region "$AWS_REGION" --profile "$AWS_PROFILE" &> /dev/null; then
        print_success "ECR repository already exists"
    else
        print_warning "ECR repository does not exist. Creating..."
        
        aws ecr create-repository \
            --repository-name "$PROJECT_NAME" \
            --image-scanning-configuration scanOnPush=true \
            --region "$AWS_REGION" \
            --profile "$AWS_PROFILE" > /dev/null
        
        print_success "ECR repository created"
    fi
}

# Build Docker image
build_image() {
    print_header "Building Docker Image"
    
    print_info "Building image: $PROJECT_NAME:$IMAGE_TAG"
    
    docker build -t "$PROJECT_NAME:$IMAGE_TAG" . --platform linux/amd64
    
    if [ $? -eq 0 ]; then
        print_success "Docker image built successfully"
    else
        print_error "Failed to build Docker image"
        exit 1
    fi
}

# Tag image for ECR
tag_image() {
    print_header "Tagging Image"
    
    docker tag "$PROJECT_NAME:$IMAGE_TAG" "$ECR_URL:$IMAGE_TAG"
    
    if [ $? -eq 0 ]; then
        print_success "Image tagged: $ECR_URL:$IMAGE_TAG"
    else
        print_error "Failed to tag image"
        exit 1
    fi
}

# Push image to ECR
push_image() {
    print_header "Pushing Image to ECR"
    
    print_info "Pushing to: $ECR_URL:$IMAGE_TAG"
    
    docker push "$ECR_URL:$IMAGE_TAG"
    
    if [ $? -eq 0 ]; then
        print_success "Image pushed successfully"
    else
        print_error "Failed to push image"
        exit 1
    fi
}

# List images in ECR
list_images() {
    print_header "ECR Images"
    
    aws ecr describe-images \
        --repository-name "$PROJECT_NAME" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --query 'sort_by(imageDetails,& imagePushedAt)[*].[imageTags[0],imagePushedAt,imageSizeInBytes]' \
        --output table
}

# Get image digest
get_digest() {
    print_header "Image Digest"
    
    DIGEST=$(aws ecr describe-images \
        --repository-name "$PROJECT_NAME" \
        --image-ids imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --query 'imageDetails[0].imageDigest' \
        --output text)
    
    if [ ! -z "$DIGEST" ]; then
        print_success "Image digest: $DIGEST"
        echo ""
        print_info "Full image URI:"
        echo "$ECR_URL@$DIGEST"
    else
        print_error "Image not found"
    fi
}

# Delete image from ECR
delete_image() {
    print_header "Delete Image from ECR"
    
    print_warning "This will delete image: $PROJECT_NAME:$IMAGE_TAG"
    read -p "Are you sure? (yes/no): " -r
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        aws ecr batch-delete-image \
            --repository-name "$PROJECT_NAME" \
            --image-ids imageTag="$IMAGE_TAG" \
            --region "$AWS_REGION" \
            --profile "$AWS_PROFILE" > /dev/null
        
        print_success "Image deleted"
    else
        print_info "Deletion cancelled"
    fi
}

# Scan image for vulnerabilities
scan_image() {
    print_header "Scanning Image for Vulnerabilities"
    
    print_info "Starting scan for: $PROJECT_NAME:$IMAGE_TAG"
    
    aws ecr start-image-scan \
        --repository-name "$PROJECT_NAME" \
        --image-id imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" > /dev/null
    
    print_info "Scan initiated. Waiting for results..."
    sleep 5
    
    aws ecr describe-image-scan-findings \
        --repository-name "$PROJECT_NAME" \
        --image-id imageTag="$IMAGE_TAG" \
        --region "$AWS_REGION" \
        --profile "$AWS_PROFILE" \
        --query 'imageScanFindings.findingSeverityCounts'
}

# Full deployment workflow
deploy() {
    print_header "Full Deployment Workflow"
    
    check_aws_cli
    check_docker
    get_account_id
    build_ecr_url
    ecr_login
    create_repository
    build_image
    tag_image
    push_image
    
    echo ""
    print_success "Deployment complete!"
    echo ""
    print_info "Image URI: $ECR_URL:$IMAGE_TAG"
    echo ""
    print_warning "Next steps:"
    echo "1. Update terraform/terraform.tfvars with this image URI:"
    echo "   container_image = \"$ECR_URL:$IMAGE_TAG\""
    echo "2. Deploy infrastructure:"
    echo "   cd terraform && terraform apply"
}

# Show usage
usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Manage Docker images in AWS ECR for Salesforce OAuth Demo

COMMANDS:
    deploy          Full workflow: build, tag, and push image to ECR
    build           Build Docker image locally
    push            Push existing image to ECR (builds if needed)
    login           Authenticate Docker with ECR
    list            List all images in ECR repository
    digest          Get image digest for specific tag
    scan            Scan image for security vulnerabilities
    delete          Delete image from ECR
    help            Show this help message

OPTIONS:
    AWS_PROFILE     Set AWS profile (default: gforce)
                    Example: AWS_PROFILE=default $0 deploy
    
    AWS_REGION      Set AWS region (default: eu-central-1)
                    Example: AWS_REGION=us-east-1 $0 deploy
    
    IMAGE_TAG       Set image tag (default: latest)
                    Example: IMAGE_TAG=v1.0.0 $0 deploy

EXAMPLES:
    # Full deployment with default settings (gforce profile, eu-central-1)
    $0 deploy
    
    # Build and push with custom tag
    IMAGE_TAG=v1.2.3 $0 deploy
    
    # Use different AWS profile
    AWS_PROFILE=default $0 deploy
    
    # Just authenticate with ECR
    $0 login
    
    # List all images
    $0 list
    
    # Scan latest image
    $0 scan
    
    # Delete specific tag
    IMAGE_TAG=old-version $0 delete
    
    # Different region and profile
    AWS_REGION=us-east-1 AWS_PROFILE=production $0 deploy

EOF
}

# Main script logic
main() {
    case "${1:-}" in
        deploy)
            deploy
            ;;
        build)
            check_docker
            build_image
            ;;
        push)
            check_aws_cli
            check_docker
            get_account_id
            build_ecr_url
            ecr_login
            
            # Build if image doesn't exist locally
            if ! docker image inspect "$PROJECT_NAME:$IMAGE_TAG" &> /dev/null; then
                build_image
            fi
            
            tag_image
            push_image
            ;;
        login)
            check_aws_cli
            get_account_id
            build_ecr_url
            ecr_login
            ;;
        list)
            check_aws_cli
            list_images
            ;;
        digest)
            check_aws_cli
            get_digest
            ;;
        scan)
            check_aws_cli
            scan_image
            ;;
        delete)
            check_aws_cli
            delete_image
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: ${1:-}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
