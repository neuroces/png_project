# Root Terraform file for Stage 1 Deployment
# Creating an ECR for containerized tool

provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "png_analysis" {
  name = var.ecr_repo_name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.png_analysis.repository_url
}
