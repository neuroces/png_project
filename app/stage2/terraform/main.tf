# Root Terraform file for FFT image analysis pipeline
# This sets up the ECR repo, S3 bucket, ECS task, and Lambda trigger

provider "aws" {
  region = var.aws_region
}

# ------------------------------
# VPC and Subnet
# ------------------------------
resource "aws_vpc" "fft_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Giving internet access. Not as secure but avoids having to set up endpoints.
resource "aws_internet_gateway" "fft_igw" {
  vpc_id = aws_vpc.fft_vpc.id
}

resource "aws_subnet" "fft_subnet" {
  vpc_id                  = aws_vpc.fft_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_route_table" "fft_route_table" {
  vpc_id = aws_vpc.fft_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.fft_igw.id
  }
}

resource "aws_route_table_association" "fft_subnet_assoc" {
  subnet_id      = aws_subnet.fft_subnet.id
  route_table_id = aws_route_table.fft_route_table.id
}


# ------------------------------
# S3 Bucket
# ------------------------------
resource "random_uuid" "bucket_suffix" {}

resource "aws_s3_bucket" "fft_input" {
  bucket = "my-images-${random_uuid.bucket_suffix.result}"
  force_destroy = true
}

output "bucket_name" {
  value = aws_s3_bucket.fft_input.bucket
  description = "Name of the S3 bucket to upload images to."
}
# ------------------------------
# IAM Role for Lambda
# ------------------------------
resource "aws_iam_role" "lambda_exec" {
  name = "lambdaFFTTriggerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ecs_run_task" {
  name = "AllowLambdaToRunECSTask"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:RunTask"
        ],
        Resource = aws_ecs_task_definition.fft_task.arn
      },
      {
        Effect = "Allow",
        Action = "iam:PassRole",
        Resource = aws_iam_role.ecs_task_exec.arn
      }
    ]
  })
}

# ------------------------------
# Lambda Function
# ------------------------------
resource "aws_lambda_function" "trigger_fft" {
  function_name = "triggerFFTContainer"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "launch_ecs_lambda.lambda_handler"
  runtime       = "python3.12"
  timeout       = 10

  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")

  environment {
    variables = {
      ECS_CLUSTER     = var.ecs_cluster_name
      TASK_DEFINITION = aws_ecs_task_definition.fft_task.arn
      SUBNET_ID       = aws_subnet.fft_subnet.id
      CONTAINER_NAME  = var.container_name
    }
  }
}

# ------------------------------
# S3 Event Notification
# ------------------------------
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_fft.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.fft_input.arn
}

resource "aws_s3_bucket_notification" "notify_lambda" {
  bucket = aws_s3_bucket.fft_input.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger_fft.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "inputs/"
    filter_suffix       = ".png"
  }

  depends_on = [aws_lambda_permission.allow_s3]
}


# ------------------------------
# ECS Task Definition
# ------------------------------

# Create log group
resource "aws_cloudwatch_log_group" "ecs_fft" {
  name              = "/ecs/fft"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "fft_cluster" {
  name = var.ecs_cluster_name
}


# Create roles with policies
resource "aws_iam_role" "ecs_task_exec" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  role       = aws_iam_role.ecs_task_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_s3_access" {
  name = "AllowS3Access"
  role = aws_iam_role.ecs_task_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = "${aws_s3_bucket.fft_input.arn}/*"
      }
    ]
  })
}

# Create task - dummy path over-riden by lambda at runtime
resource "aws_ecs_task_definition" "fft_task" {
  family                   = "fft-analysis-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_exec.arn
  task_role_arn            = aws_iam_role.ecs_task_exec.arn

  container_definitions = jsonencode([
    {
      name      = var.container_name,
      image     = var.ecr_image_uri,
      command   = ["python", "plot_fft.py"],
      environment = [
        {
          name  = "BUCKET",
          value = "dummy-bucket"
        },
        {
          name  = "KEY",
          value = "dummy-key"
        }
      ],
      essential = true,
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = "/ecs/fft",
          awslogs-region        = var.aws_region,
          awslogs-stream-prefix = "fft"
        }
      }
    }
  ])
  depends_on = [aws_cloudwatch_log_group.ecs_fft]
}
