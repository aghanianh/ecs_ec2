  resource "aws_vpc" "this" {
    cidr_block = var.cidr_block
    tags = {
      Name = var.vpc_name
    }
  }

  resource "aws_subnet" "public_subnet_1" {
    vpc_id                  = aws_vpc.this.id
    cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, 0)
    map_public_ip_on_launch = true
    availability_zone        = "us-east-1a"

    tags = {
      Name = "${var.vpc_name}_public_subnet_1"
    }
  }

  resource "aws_subnet" "public_subnet_2" {
    vpc_id                  = aws_vpc.this.id
    cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, 3)
    map_public_ip_on_launch = true
    availability_zone        = "us-east-1b"

    tags = {
      Name = "${var.vpc_name}_public_subnet_2"
    }
  }


  resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id
    tags = {
      Name = "${var.vpc_name}_IGW"
    }
  }

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


  resource "aws_route_table_association" "public1" {
    route_table_id = aws_route_table.this.id
    subnet_id      = aws_subnet.public_subnet_1.id
  }
    resource "aws_route_table_association" "public2" {
    route_table_id = aws_route_table.this.id
    subnet_id      = aws_subnet.public_subnet_2.id
  }




  resource "aws_security_group" "this" {
    vpc_id = aws_vpc.this.id
    ingress {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
      from_port   = var.container_port 
      to_port     = var.container_port #add
      protocol    = "tcp"
      security_groups = [aws_security_group.alb_sg.id]
    }
      egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
      Name = "${var.vpc_name}_SG"
    }
  }


  resource "aws_ecs_cluster" "this" {
    name = var.cluster_name
  }


  resource "aws_iam_role" "ecs_instance_role" {
    name = "ecs-instance-role"

    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
        }
      ]
    })
  }

  resource "aws_iam_role_policy_attachment" "ecs_instance_role_attachment" {
    role       = aws_iam_role.ecs_instance_role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  }

  resource "aws_iam_instance_profile" "ecs_instance_profile" {
    name = "ecs-instance-profile"
    role = aws_iam_role.ecs_instance_role.name
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


  resource "aws_ecs_task_definition" "this" {
    family                   = "ecs-task" 
    network_mode             = "bridge"  
    requires_compatibilities = ["EC2"] 
    cpu                      = var.task_definition_cpu
    memory                   = "512" 

    execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
    container_definitions = jsonencode([
      {
        name      = var.container_name
        image     = var.image_name #change
        essential = true
        memory    = 512 #change
        portMappings = [
          {
            containerPort = var.container_port
            hostPort      = var.container_port 
          }
        ]
      }
      
    ])
  }

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

  #  network_configuration {
  #    subnets         = [aws_subnet.this.id]
  #    security_groups = [aws_security_group.this.id]
  #  }
  }
  resource "aws_security_group" "alb_sg" {
    vpc_id = aws_vpc.this.id

    ingress {
      from_port   = 80  
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "ALB_SG"
    }
  }

  resource "aws_lb" "ecs_alb" {
    name               = "ecs-load-balancer"
    internal           = true  
    load_balancer_type = "application"
    security_groups    = [aws_security_group.alb_sg.id]
    subnets           = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]  
  }


  resource "aws_lb_target_group" "ecs_tg" {
    name        = "ecs-target-group"
    port        = var.container_port
    protocol    = "HTTP"
    vpc_id      = aws_vpc.this.id 
    target_type = "instance"
  }

  resource "aws_lb_listener" "http_listener" {
    load_balancer_arn = aws_lb.ecs_alb.arn
    port              = var.container_port
    protocol          = "HTTP"

    default_action {
      type             = "forward"
      target_group_arn = aws_lb_target_group.ecs_tg.arn
    }
  }


  data "aws_ami" "amazon_linux_2" {
    most_recent = true

    filter {
      name   = "virtualization-type"
      values = ["hvm"]
    }

    filter {
      name   = "owner-alias"
      values = ["amazon"]
    }

    filter {
      name   = "name"
      values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
    }

    owners = ["amazon"]
  }


  resource "aws_instance" "ecs_instance" {
    ami                         = data.aws_ami.amazon_linux_2.id 
    instance_type               = "t2.micro"
    subnet_id                   = aws_subnet.public_subnet_1.id
    vpc_security_group_ids      = [aws_security_group.this.id]
    associate_public_ip_address = true
    iam_instance_profile        = aws_iam_instance_profile.ecs_instance_profile.name

    user_data = <<-EOF
                #!/bin/bash
                echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
                EOF

    tags = {
      Name = "ecs-instance"
    }
  }

  output "ip_addr" {
    value = aws_instance.ecs_instance.public_ip
  }

  output "ecs_service_name" {
    value = aws_ecs_service.ecs_service.name
  }