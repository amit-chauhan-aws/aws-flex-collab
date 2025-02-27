
resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.cluster_name}"
  retention_in_days = var.log_group_retention_in_days
}

# Task Role and Execution Role
resource "aws_iam_role" "task_role" {
  name = "ecs-task-role-${var.cluster_name}"

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

  # Add permissions for Secret Manager access
  inline_policy {
    name = "secrets-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["secretsmanager:GetSecretValue"]
          Resource = [for secret in var.secrets : "arn:aws:secretsmanager:${var.aws_region}:${var.account_id}:secret:${secret}"]
        }
      ]
    })
  }
}

resource "aws_iam_role" "execution_role" {
  name = "ecs-execution-role-${var.cluster_name}"

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

  # Add permissions for logging and image pull
  inline_policy {
    name = "execution-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/ecs/${var.cluster_name}*"]
        },
        {
          Effect   = "Allow"
          Action   = ["ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage", "ecr:GetAuthorizationToken"]
          Resource = "*"
        }
      ]
    })
  }
}

# Task Definitions and Services
resource "aws_ecs_task_definition" "this" {
  for_each = { for service in var.services : service.name => service }

  family                   = each.value.name
  network_mode             = "awsvpc"
  task_role_arn            = aws_iam_role.task_role.arn
  execution_role_arn       = aws_iam_role.execution_role.arn
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  container_definitions = jsonencode([
    {
      name      = each.value.name
      image     = each.value.image
      essential = true
      portMappings = [
        {
          containerPort = each.value.container_port
          hostPort      = each.value.container_port
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = each.value.name
        }
      }
    }
  ])
}

resource "aws_ecs_service" "this" {
  for_each = { for service in var.services : service.name => service }

  name            = each.value.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this[each.key].arn
  desired_count   = each.value.desired_count

  launch_type = "FARGATE"
  load_balancer {
    target_group_arn = aws_lb_target_group.this[each.key].arn
    container_name   = each.key
    container_port   = each.value.container_port
  }
  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.ecs_service.id]
  }
}

# Autoscaling for ECS service



resource "aws_appautoscaling_target" "this" {
  for_each           = { for service in var.services : service.name => service }
  max_capacity       = each.value.max_capacity
  min_capacity       = each.value.min_capacity
  resource_id        = "service/${var.cluster_name}/${each.value.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.this]
}

resource "aws_appautoscaling_policy" "memory" {
  for_each           = { for service in var.services : service.name => service }
  name               = each.value.name
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 80
  }
}


# Application Load Balancer
resource "aws_lb" "this" {
  name               = "${var.cluster_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = var.public_subnets
}

# Target Group
resource "aws_lb_target_group" "this" {
  for_each = { for service in var.services : service.name => service }

  name        = "${each.value.name}-tg"
  target_type = "ip"
  port        = each.value.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Invalid route"
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "path_based_routing" {
  for_each = aws_lb_target_group.this

  listener_arn = aws_lb_listener.http.arn
  #priority     = 100 + each.value

  condition {
    path_pattern {
      values = ["/${each.key}*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = each.value.arn
  }
}

# Security Groups
resource "aws_security_group" "ecs_service" {
  name        = "ecs-service-sg"
  description = "Allow traffic for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.services[0].container_port
    to_port     = var.services[0].container_port
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

resource "aws_security_group" "lb" {
  name        = "lb-sg"
  description = "Allow HTTP traffic for ALB"
  vpc_id      = var.vpc_id

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

# Monitoring
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "HighCPU"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.alarms.cpu_high_threshold
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "HighMemory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.alarms.memory_high_threshold
}

resource "aws_cloudwatch_metric_alarm" "request_5xx_rate" {
  alarm_name          = "High5xxRate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = var.alarms.request_5xx_rate_threshold
}

