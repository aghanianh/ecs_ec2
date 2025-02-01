resource "aws_ecs_cluster" "this" {
  name = var.cluster_name
}

resource "aws_vpc" "this" {
  cidr_block = var.cidr_block
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "this" {
  vpc_id                  = aws_vpc.this.id
  map_public_ip_on_launch = true
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 2, 0)
  tags = {
    Name = "${var.vpc_name}_public_subnet"
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

resource "aws_route_table_association" "this" {
  route_table_id = aws_route_table.this.id
  subnet_id      = aws_subnet.this.id
}

resource "aws_security_group" "this" {
  vpc_id = aws_vpc.this.id
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
  tags = {
    Name = "${var.vpc_name}_SG"
  }
}

resource "aws_iam_role" "this" {
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

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = aws_iam_role.this.name
}

resource "aws_ecs_task_definition" "this" {
  family                   = "ecs-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.this.arn
  container_definitions = jsonencode([
    {
      name      = var.container_name
      image     = var.ecr_repo_url
      essential = true
      portMappings = [
        {
          containerPort = 5000
          hostPort      = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "ecs_service" {
  name            = var.ecs_service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "EC2"

  network_configuration {
    subnets          = [aws_subnet.this.id]
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = true
  }
}

resource "aws_instance" "ecs_instance" {
  ami                         = "ami-0c02fb55956c7d316" # Amazon ECS-optimized AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.this.id
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