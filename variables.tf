variable "cluster_name" {
  description = "The name of the ECS cluster"
  default = "ecs-cluster"
  type        = string
}

variable "vpc_name" {
  description = "The name of the VPC"
  default = "ecs-vpc"
  type        = string
}

variable "cidr_block" {
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
  type        = string
}

variable "container_name" {
  description = "The name of the container"
  default = "my-container"
  type        = string
}

variable "ecr_repo_url" {
  description = "The URL of the ECR repository"
  type        = string
  default = "985539765873.dkr.ecr.us-east-1.amazonaws.com/my-ecr-repo:latest"
}

variable "ecs_service_name" {
  description = "The name of the ECS service"
  type        = string
  default     = "ecs-name"
}

variable "task_definition_cpu" {
  type = string 
  default = "256"
}

variable "container_port" {
  type = number
  default = 5000
}

variable "desired_count" {
  type = number 
  default = 2
    
}

variable "image_name" {
  type = string 

}

