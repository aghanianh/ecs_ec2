module "ecs" {
  source = "./module/ecs"
  vpc_name = "ECS_VPC" 
  image_name = var.image_name
   
}