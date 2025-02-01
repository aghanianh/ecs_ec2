# modules/ecs/variables.tf

variable "cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
}

variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "container_name" {
  description = "The name of the container"
  type        = string
}

variable "ecr_repo_url" {
  description = "The URL of the ECR repository"
  type        = string
}

variable "ecs_service_name" {
  description = "The name of the ECS service"
  type        = string
}