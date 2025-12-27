
variable "vpc_id" { type = string }
variable "subnet_a_id" { type = string }
variable "subnet_b_id" { type = string }
variable "allow_sg_id" { type = string }
variable "alb_sg_id" { type = string }
variable "instance_type" { type = string }
variable "public_key_path" { type = string }
variable "user_data" { type = string }

# Key pair
resource "aws_key_pair" "key_tf" {
  key_name   = "key-tf"
  public_key = file(var.public_key_path)
}

# IAM role EC2 can assume
resource "aws_iam_role" "ec2_dynamo_role" {
  name = "ec2-dynamodb-fullaccess-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

# Attach AWS managed DynamoDB full access
resource "aws_iam_role_policy_attachment" "ec2_dynamo_full" {
  role       = aws_iam_role.ec2_dynamo_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Attach AWS managed SQS full access (for sending)
resource "aws_iam_role_policy_attachment" "ec2_sqs_full" {
  role       = aws_iam_role.ec2_dynamo_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

resource "aws_iam_policy" "cw_agent_policy" {
  name = "ec2-cloudwatch-logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_cw_agent_policy" {
  role       = aws_iam_role.ec2_dynamo_role.name
  policy_arn = aws_iam_policy.cw_agent_policy.arn
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2_dynamo_profile" {
  name = "ec2-dynamodb-fullaccess-profile"
  role = aws_iam_role.ec2_dynamo_role.name
}

# ALB
resource "aws_lb" "app_lb" {
  name               = "pastebin-app-lb"
  load_balancer_type = "application"
  internal           = false
  subnets            = [var.subnet_a_id, var.subnet_b_id]
  security_groups    = [var.alb_sg_id]
}

resource "aws_lb_target_group" "app_tg" {
  name        = "pastebin-app-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  depends_on        = [aws_lb_target_group.app_tg]
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# DynamoDB tables
resource "aws_dynamodb_table" "users" {
  name         = "Users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "username"
  attribute {
    name = "username"
    type = "S"
  }
}

resource "aws_dynamodb_table" "pastes" {
  name         = "Pastes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
}


# EC2 instances
resource "aws_instance" "web" {
  depends_on             = [aws_sqs_queue.pastebin-backend-queue]
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.key_tf.key_name
  vpc_security_group_ids = [var.allow_sg_id]
  subnet_id              = var.subnet_a_id
  user_data              = templatefile("${path.module}/user_data.sh", {
    queue_url              = aws_sqs_queue.pastebin-backend-queue.url
    cloudwatch_log_group   = aws_cloudwatch_log_group.pastebin-backend-log-group.name
  })
  iam_instance_profile        = aws_iam_instance_profile.ec2_dynamo_profile.name
  user_data_replace_on_change = true
  tags = {
    Name               = "first-tf-instance"
    Environment        = "development"
    Project            = "pastebin"
    Owner              = "terraform"
    CreatedBy          = "Terraform"
    ManagedBy          = "Terraform"
    Terraform          = "true"
    TerraformVersion   = "1.0"
    TerraformWorkspace = "default"
    TerraformModule    = "main"
    TerraformTimestamp = timestamp()
  }
}

resource "aws_instance" "web2" {
  depends_on             = [aws_sqs_queue.pastebin-backend-queue]
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.key_tf.key_name
  vpc_security_group_ids = [var.allow_sg_id]
  subnet_id              = var.subnet_b_id
  user_data              = templatefile("${path.module}/user_data.sh", {
    queue_url              = aws_sqs_queue.pastebin-backend-queue.url
    cloudwatch_log_group   = aws_cloudwatch_log_group.pastebin-backend-log-group.name
  })
  iam_instance_profile        = aws_iam_instance_profile.ec2_dynamo_profile.name
  user_data_replace_on_change = true
  tags = {
    Name               = "first-tf-instance"
    Environment        = "development"
    Project            = "pastebin"
    Owner              = "terraform"
    CreatedBy          = "Terraform"
    ManagedBy          = "Terraform"
    Terraform          = "true"
    TerraformVersion   = "1.0"
    TerraformWorkspace = "default"
    TerraformModule    = "main"
  }
}

resource "aws_lb_target_group_attachment" "app_tg_attachment1" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web.id
  port             = 8000
}

resource "aws_lb_target_group_attachment" "app_tg_attachment2" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web2.id
  port             = 8000
}

# AMI lookup within module

data "aws_ami" "amazon_linux" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_cloudwatch_log_group" "pastebin-backend-log-group" {
  name              = "/ec2/pastebin-backend-log-group"
  retention_in_days = 14
}

resource "aws_sqs_queue" "pastebin-backend-queue" {
  name                       = "pastebin-backend-queue"
  visibility_timeout_seconds = 30
}



output "alb_dns_name" { value = aws_lb.app_lb.dns_name }
output "instance_one_ip" { value = aws_instance.web.public_ip }
output "instance_two_id" { value = aws_instance.web2.public_ip }
output "queue_url" { value = aws_sqs_queue.pastebin-backend-queue.arn }