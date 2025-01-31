module "ecs" {
  source = "./modules/ecs"

  cluster_name    = var.cluster_name
  cidr_block      = var.cidr_block
  vpc_name        = var.vpc_name
  container_name  = var.container_name
  ecr_repo_url    = var.ecr_repo_url
  ecs_service_name = var.ecs_service_name
}

output "ip_addr" {
  value = module.ecs.ip_addr
}