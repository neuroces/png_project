#!/bin/bash
set -e
ECR_URL=$1
REGION=$2
# Ensure AWS CLI and Docker are installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it before running this script."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install it before running this script."
    exit 1
fi

# Login to AWS ECR
echo "🔑 Logging into AWS ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin "$ECR_URL"
if [ $? -ne 0 ]; then
    echo "❌ ECR login failed!"
    exit 1
fi

cd ../docker

# Build Docker image for x86_64 (amd64) and push
echo "🛠 Building Docker image..."
docker buildx build --platform linux/amd64 -t $ECR_URL:latest --push .


echo "✅ Docker image pushed to $ECR_URL:latest"