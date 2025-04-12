variable "aws_region" {
  default = "us-east-1"
}
variable "ecs_cluster_name" {
  default = "my-ecs-cluster"
}
variable "container_name" {
  default = "fft-analyzer"
}
variable "ecr_image_uri" {}
