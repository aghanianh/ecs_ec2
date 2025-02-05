data "aws_availability_zones" "available" { }

  locals {
    azs_count =  2
    azs_names = data.aws_availability_zones.available.names 
  }

  resource "aws_vpc" "this" {
    cidr_block = var.cidr_block
    enable_dns_hostnames = true 
    enable_dns_support = true 
    tags = {
      Name = var.vpc_name
    }
  }

  resource "aws_subnet" "public_subnet" {
    count = local.azs_count 
    vpc_id                  = aws_vpc.this.id
    cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, 10 + count.index)
    availability_zone       = local.azs_names[count.index]
    map_public_ip_on_launch = true
    tags = {
      Name = "${local.azs_names[count.index]}_public_subnet"
    }
  }

  resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id
    tags = {
      Name = "${var.vpc_name}_IGW"
    }
  }

#  resource "aws_eip" "this" {
#    count = local.azs_count
#    depends_on = [ aws_internet_gateway.this ]
#  }

  resource "aws_route_table" "this" {
    vpc_id = aws_vpc.this.id
    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.this.id
    }
    tags = {
      Name = "${var.vpc_name}_route_table"
    }
  }


  resource "aws_route_table_association" "this" {
    count = local.azs_count
    route_table_id = aws_route_table.this.id
    subnet_id      = aws_subnet.public_subnet[count.index].id
  }


  resource "aws_ecs_cluster" "main" {
    name = var.cluster_name
  }


  data "aws_iam_policy_document" "ecs_node_doc" {
    statement {
      actions = ["sts:AssumeRole"]
      effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


  resource "aws_iam_role" "ecs_node_role" {
   name_prefix        = "ecs-node-role"
   assume_role_policy = data.aws_iam_policy_document.ecs_node_doc.json
}


  resource "aws_iam_role_policy_attachment" "ecs_instance_role_attachment" {
    role       = aws_iam_role.ecs_node_role.name 
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  }

  resource "aws_iam_instance_profile" "ecs_node" {
    name_prefix = "ecs-node-profile"
    path        = "/ecs/instance/"
    role        = aws_iam_role.ecs_node_role.name
  }


  resource "aws_iam_role" "ecs_task_execution_role" {
    name = "ecs-task-execution-role"

    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
        }
      ]
    })
  }

  resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
    role       = aws_iam_role.ecs_task_execution_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  }
  resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_ecr" {
   role       = aws_iam_role.ecs_task_execution_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  }




resource "aws_security_group" "ecs_node_sg" {
  name_prefix = "ecs-node-sg"
  vpc_id      = aws_vpc.this.id 

  egress {
    description  = "Allow all outbound traffic"
    from_port    = 0
    to_port      = 0
    protocol     = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []  
    prefix_list_ids   = []  
    security_groups   = []
    self              = false  
  }
}


data "aws_ssm_parameter" "ecs_optimized_ami" {
  name   = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id"
}

  resource "aws_launch_template" "ecs_ec2" {
    name_prefix = "ecs-ec2"
    image_id = data.aws_ssm_parameter.ecs_optimized_ami.value
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.ecs_node_sg.id]
    iam_instance_profile {
      arn = aws_iam_instance_profile.ecs_node.arn 
    }
    user_data = base64encode( <<EOF
        #!/bin/bash
        echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config;
      EOF
    )
  }

  resource "aws_autoscaling_group" "ecs" {
  name_prefix               = "ecs-asg"
  vpc_zone_identifier       = aws_subnet.public_subnet[*].id
  min_size                  = 2
  max_size                  = 4
  health_check_grace_period = 0
  health_check_type         = "EC2"
  protect_from_scale_in     = false

  launch_template {
    id      = aws_launch_template.ecs_ec2.id
    version = aws_launch_template.ecs_ec2.latest_version

  }

  tag {
    key                 = "Name"
    value               = "ecs-cluster"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "main" {
  name = "capacity_ecs_ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    base              = 1
    weight            = 100
  }
}


resource "aws_ecs_task_definition" "this" {
  family                   = "ecs-task" 
  network_mode             = "awsvpc"   
  requires_compatibilities = ["EC2"] 
  cpu                      = var.task_definition_cpu
  memory                   = "512" 

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.image_name
      essential = true
      memory    = 512
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port 
        }
      ]
    }
  ])
}

resource "aws_security_group" "ecs_task" {
  name_prefix = "ecs-task-sg-"
  description = "Allow all traffic within the VPC"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_service" "app" {
  name            = "app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 2

  network_configuration {
    security_groups = [aws_security_group.ecs_task.id]
    subnets         = aws_subnet.public_subnet[*].id
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    base              = 1
    weight            = 100
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name = var.container_name
    container_port = var.container_port
  }
}

resource "aws_security_group" "http" {
  name_prefix = "http-sg-"
  description = "Allow all HTTP/HTTPS traffic from public"
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = [80, 443]
    content {
      protocol    = "tcp"
      from_port   = ingress.value
      to_port     = ingress.value
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "main" {
  name               = "demo-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnet[*].id
  security_groups    = [aws_security_group.http.id]
}

resource "aws_lb_target_group" "app" {
  name_prefix = "app-"
  vpc_id      = aws_vpc.this.id
  protocol    = "HTTP"
  port        = 5000
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/"
    port                = 5000
    matcher             = 200
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.id
  }
}

output "alb_url" {
  value = aws_lb.main.dns_name
}
  /*
  resource "aws_ecs_service" "ecs_service" {
    name            = var.ecs_service_name
    cluster         = aws_ecs_cluster.this.id
    task_definition = aws_ecs_task_definition.this.arn
    desired_count   = var.desired_count 
    launch_type     = "EC2"
      load_balancer {
      target_group_arn = aws_lb_target_group.ecs_tg.arn
      container_name   = var.container_name
      container_port   = var.container_port
    }

    network_configuration {
      subnets         = [aws_subnet.this.id]
      security_groups = [aws_security_group.this.id]
    }
  }
*/

/*
  resource "aws_lb_target_group" "ecs_tg" {
    name        = "ecs-target-group"
    port        = var.container_port
    protocol    = "HTTP"
    vpc_id      = aws_vpc.this.id 
    target_type = "instance" ## will be changed to ip
  }
*/
/*
  resource "aws_lb_listener" "http_listener" {
    load_balancer_arn = aws_lb.ecs_alb.arn
    port              = var.container_port
    protocol          = "HTTP"

    default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.ecs_tg.arn
    }
  }
*/

/*
  output "ip_addr" {
    value = aws_instance.ecs_instance.public_ip
  }
*/
/*
  output "ecs_service_name" {
    value = aws_ecs_service.ecs_service.name
  }
*/
/*
  output "lb_dns" {
    value = aws_lb.ecs_alb.dns_name
  }
*/
