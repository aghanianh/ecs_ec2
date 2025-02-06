# Get Availability Zones
data "aws_availability_zones" "available" {}

locals {
  azs_count = 2
  azs_names = data.aws_availability_zones.available.names
}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = var.vpc_name
  }
}

# Public Subnets
resource "aws_subnet" "public_subnet" {
  count                   = local.azs_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index)
  availability_zone       = local.azs_names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${local.azs_names[count.index]}_public_subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.vpc_name}_IGW"
  }
}

# Route Table
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

# Associate Subnets with Route Table
resource "aws_route_table_association" "this" {
  count          = local.azs_count
  route_table_id = aws_route_table.this.id
  subnet_id      = aws_subnet.public_subnet[count.index].id
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.cluster_name
}

# IAM Policy Document for ECS Nodes
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

# IAM Role for ECS EC2 Instances
resource "aws_iam_role" "ecs_node_role" {
  name_prefix        = "ecs-node-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_node_doc.json
}

# Attach Policies to ECS Instance Role
resource "aws_iam_role_policy_attachment" "ecs_instance_role_attachment" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ecs_node" {
  name = "ecs-node-instance-profile"
  role = aws_iam_role.ecs_node_role.name
}

# Security Group for ECS Nodes
resource "aws_security_group" "ecs_node_sg" {
  name_prefix = "ecs-node-sg"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_task" {
  name_prefix = "ecs-task-sg"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template for ECS EC2 Instances
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs_ec2" {
  name_prefix          = "ecs-ec2"
  image_id             = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type        = "t2.micro"
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

# Auto Scaling Group for ECS Nodes
resource "aws_autoscaling_group" "ecs" {
  name_prefix         = "ecs-asg"
  vpc_zone_identifier = aws_subnet.public_subnet[*].id
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.ecs_ec2.id
    version = aws_launch_template.ecs_ec2.latest_version
  }

  tag {
    key                 = "Name"
    value               = "ecs-instance"
    propagate_at_launch = true
  }
}

# Load Balancer for ECS Service
resource "aws_lb" "main" {
  name               = "demo-alb"
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnet[*].id
  security_groups    = [aws_security_group.ecs_task.id]
}

resource "aws_lb_target_group" "app" {
  name_prefix = "app-"
  vpc_id      = aws_vpc.this.id
  protocol    = "HTTP"
  port        = 5000
  target_type = "ip"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.id
  port              = 5000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.id
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name_prefix = "ecs-task-execution-role"

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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "this" {
  family                   = "ecs-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.task_definition_cpu
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions    = jsonencode([
    {
      name      = var.container_name
      image     = var.image_name
      essential = true
      memory    = 512
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "this" {
  name            = "flask-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 2
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.public_subnet[*].id
    security_groups  = [aws_security_group.ecs_task.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.container_name
    container_port   = 5000
  }

  depends_on = [aws_lb_listener.http]
}

# Output ALB URL
output "alb_url" {
  value = aws_lb.main.dns_name
}