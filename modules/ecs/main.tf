#create ECS IAM role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.ecs_cluster_name}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = "TerraformECSExecutionRolePolicy"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create an ECS cluster
resource "aws_ecs_cluster" "app_cluster" {
  name = "${var.ecs_cluster_name}"
}

resource "aws_ecs_task_definition" "backend" {
  family                   = "backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = "backend"
    image = "<account-id>.dkr.ecr.<region>.amazonaws.com/backend:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 5200  # Backend port
      hostPort      = 5200
    }]
    environment = [{
      name  = "ATLAS_URI"
      value = var.atlas_cluster_connection_string
    }]
    
  }])

  runtimePlatform = {
    operatingSystemFamily = "LINUX"
  }
}

resource "aws_ecs_service" "backend" {
  name            = "backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = var.use_public_ip  
    security_groups  = [aws_security_group.backend_sg.id]
  }

  # Enable Service Discovery
  service_registries {
    registry_arn = aws_service_discovery_service.backend.arn
    container_name = "backend"
  }
}

resource "aws_service_discovery_private_dns_namespace" "private" {
  name        = "test"
  description = "Private dns namespace for service discovery"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "this" {
  name = "backend"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.private.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 2
  }
}

resource "aws_ecs_task_definition" "frontend" {
  family                   = "frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = "frontend"
    image = "<account-id>.dkr.ecr.<region>.amazonaws.com/frontend:latest"
    essential = true
    portMappings = [{
      containerPort = 8080  # Frontend port
      hostPort      = 8080
    }]
  }])

  runtimePlatform = {
    operatingSystemFamily = "LINUX"
  }
}

resource "aws_ecs_service" "frontend" {
  name            = "frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  launch_type     = "FARGATE"
  desired_count   = 2

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = var.use_public_ip 
    security_groups  = [aws_security_group.frontend_sg.id]
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "frontend"
    container_port   = 8080
  }
}

resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Allow HTTP/HTTPS traffic to frontend"
  vpc_id      = var.vpc_id

  # Allow HTTP/HTTPS from the internet
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [var.alb_sg_id]
  }

  # Allow outbound traffic to the backend
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow traffic from frontend to backend"
  vpc_id      = var.vpc_id

  # Allow inbound traffic from the frontend
  ingress {
    from_port   = 5200
    to_port     = 5200
    protocol    = "tcp"
    security_groups = [aws_security_group.frontend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}