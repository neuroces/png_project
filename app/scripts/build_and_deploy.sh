#!/bin/bash
set -e
IMAGE_URI=$1
ECR_URL=$2
REGION=$3
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
docker buildx build --platform linux/amd64 -t $IMAGE_URI --push .


echo "✅ Docker image pushed to $IMAGE_URI"