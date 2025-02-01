module "ecs" {
  source = "./module/ecs"

  cluster_name    = var.cluster_name
  vpc_name        = var.vpc_name
  cidr_block      = var.cidr_block
  container_name  = var.container_name
  ecr_repo_url    = var.ecr_repo_url
  ecs_service_name = var.ecs_service_name
}

output "ecs_instance_public_ip" {
  value = module.ecs.ip_addr
}

output "ecs_service_name" {
  value = module.ecs.ecs_service_name
}