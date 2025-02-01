module "ecs" {
  source           = "./module/ecs"
  cluster_name     = "my-cluster"       
  container_name   = "my-container"     
  ecs_service_name = "my-service-name"
  vpc_name         = "ECS_VPC"
  cidr_block       = "10.0.0.0/16"
  ecr_repo_url     = "985539765873.dkr.ecr.us-east-1.amazonaws.com/my-ecr-repo:latest"
}
output "ecs_instance_public_ip" {
  value = module.ecs.ip_addr
}

output "ecs_service_name" {
  value = module.ecs.ecs_service_name
}