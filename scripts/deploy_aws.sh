#!/bin/bash
set -e

# Deploy stage 1
echo "🔧 Deploying Stage 1: ECR setup..."
cd ../app/stage1/terraform
terraform init
terraform apply -auto-approve
ECR_URL=$(terraform output -raw ecr_repository_url)
cd ../../scripts

# Build and push Docker image
echo "🐳 Building and pushing Docker image..."
chmod +x ./build_and_deploy.sh
./build_and_deploy.sh "$ECR_URL" "us-east-1"