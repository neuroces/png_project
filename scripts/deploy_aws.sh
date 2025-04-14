#!/bin/bash
set -e

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
  echo "❌ Terraform could not be found. Please install Terraform and try again."
  exit 1
fi

# # Deploy stage 1
echo "🔧 Deploying Stage 1: ECR setup..."
cd ../app/stage1/terraform
terraform init
terraform apply -auto-approve
ECR_URL=$(terraform output -raw ecr_repository_url)
IMAGE_URI="${ECR_URL}:latest"
cd ../../scripts

# Build and push Docker image
echo "🐳 Building and pushing Docker image..."
chmod +x ./build_and_deploy.sh
./build_and_deploy.sh "$IMAGE_URI" "us-east-1"

echo "📦 Packaging Lambda function..."
cd ../stage2/lambda
if [ ! -f "launch_ecs_lambda.py" ]; then
  echo "❌ Lambda function script not found!"
  exit 1
fi
zip ../terraform/lambda.zip launch_ecs_lambda.py > /dev/null

# Deploy stage 2
echo "🔧 Deploying Stage 2: S3 bucket and Trigger"
cd ../terraform
terraform init
terraform apply -auto-approve -var="ecr_image_uri=$IMAGE_URI"
BUCKET_NAME=$(terraform output -raw bucket_name)


echo "🚀 Deployment complete!"
echo "🔑 Bucket name for images: $BUCKET_NAME"