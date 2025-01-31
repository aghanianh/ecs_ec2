variable "aws_region" {
  default = "us-east-1"
}

variable "cluster_name" {
  type = string
}

variable "cidr_block" {
  default = "10.0.0.0/16"
}

variable "vpc_name" {
  default = "ECS VPC"
}

variable "container_name" {
  type = string
}

variable "ecr_repo_url" {
  type = string
}

variable "ecs_service_name" {
  type = string
}