module "ecs" {
  source = "./module/ecs"

  cluster_name    = "my-ecs-cluster"
  vpc_name        = "my-vpc"
  cidr_block      = "10.0.0.0/16"
  container_name  = "my-container"
  ecr_repo_url    = "123456789012.dkr.ecr.us-east-1.amazonaws.com/my-repo:latest"
  ecs_service_name = "my-ecs-service"
}

output "ecs_instance_public_ip" {
  value = module.ecs.ip_addr
}

output "ecs_service_name" {
  value = module.ecs.ecs_service_name
}