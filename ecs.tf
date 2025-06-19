resource "aws_ecr_repository" "transaction_processor" {
  name         = "${local.name_prefix}-transaction-processor"
  tags         = local.common_tags
  force_delete = true
}

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"
  tags = local.common_tags
}

resource "aws_security_group" "ecs_tasks" {
  name   = "${local.name_prefix}-ecs-tasks"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${local.name_prefix}-processor"
  retention_in_days = var.lambda_log_retention_days
  tags              = local.common_tags
}

resource "aws_ecs_task_definition" "transaction_processor" {
  family                   = "${local.name_prefix}-processor"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "transaction-processor"
      image     = "${aws_ecr_repository.transaction_processor.repository_url}:latest"
      essential = true
      environment = [
        { name = "DYNAMODB_TABLE", value = aws_dynamodb_table.transactions.name }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = local.common_tags
}
