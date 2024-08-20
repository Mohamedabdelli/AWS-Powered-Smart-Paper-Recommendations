
data "aws_caller_identity" "current" {}

# ECS Cluster
resource "aws_ecs_cluster" "my_cluster" {
  name = "app-cluster"
}

# ECR Repository
resource "aws_ecr_repository" "app_ecr_repo" {
  name = "streamlit-app"
  image_scanning_configuration {
    scan_on_push = true
  }
  force_delete = true
}

# Docker Packaging
resource "null_resource" "docker_packaging" {
  depends_on = [aws_ecr_repository.app_ecr_repo]

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${var.region_name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region_name}.amazonaws.com"
  }

  provisioner "local-exec" {
    command = <<EOT
docker build -t ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region_name}.amazonaws.com/streamlit-app:latest -f front-end/Dockerfile front-end
EOT
  }

  provisioner "local-exec" {
    command = <<EOT
docker images -q ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region_name}.amazonaws.com/streamlit-app:latest || (echo "Image build failed"; exit 1)
EOT
  }

  provisioner "local-exec" {
    command = "docker push ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region_name}.amazonaws.com/streamlit-app:latest"
  }

  triggers = {
    "run_at" = timestamp()
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "app-task"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "app-task",
      "image": "${aws_ecr_repository.app_ecr_repo.repository_url}:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8501,
          "hostPort": 8501
        }
      ],
      "memory": 512,
      "cpu": 256,
      "environment": [
        {
          "name": "base_url",
          "value": "${aws_api_gateway_deployment.rest_api.invoke_url}"
        }
      ]
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecsTaskS3Policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# VPC and Subnets
resource "aws_default_vpc" "default_vpc" {}

resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "us-east-1b"
}

# Application Load Balancer
resource "aws_alb" "application_load_balancer" {
  name               = "load-balancer-dev"
  load_balancer_type = "application"
  subnets = [
    aws_default_subnet.default_subnet_a.id,
    aws_default_subnet.default_subnet_b.id
  ]
  security_groups = [aws_security_group.load_balancer_security_group.id]
}

# Load Balancer Security Group
resource "aws_security_group" "load_balancer_security_group" {
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
}

# Target Group
resource "aws_lb_target_group" "target_group" {
  name        = "target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id
}

# Load Balancer Listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

# ECS Service
resource "aws_ecs_service" "app_service" {
  name            = "app-first-service"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  launch_type     = "FARGATE"
  desired_count   = 3

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "app-task"
    container_port   = 8501
  }

  network_configuration {
    subnets          = [aws_default_subnet.default_subnet_a.id, aws_default_subnet.default_subnet_b.id]
    assign_public_ip = true
    security_groups  = [aws_security_group.service_security_group.id]
  }
}

# Service Security Group
resource "aws_security_group" "service_security_group" {
  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Output
output "app_url" {
  value = aws_alb.application_load_balancer.dns_name
}
