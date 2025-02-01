<<<<<<< HEAD
variable "cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "ECS_VPC"
}

variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
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
=======
variable "cluster_name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC"
  type        = string
  default     = "ECS_VPCs"
}

variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
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
>>>>>>> 9e61a7c726e3482c44649c24077d604d28ad37e5
