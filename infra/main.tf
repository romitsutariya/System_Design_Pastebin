provider "aws" {
  region = "us-east-1"
}

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

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "example-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "vpc-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "a_public" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b_public" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-b"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id
  dynamic "ingress" {
    for_each = var.ports
    iterator = port
    content {
      description      = "TLS from VPC"
      from_port        = port.value
      to_port          = port.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    "Name" = "pastebin-backend-sg"
  }
}

resource "aws_key_pair" "key-tf" {
  key_name   = "key-tf"
  public_key = file("${path.module}/keys/id_rsa.pub")
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

# Instance profile for EC2
resource "aws_iam_instance_profile" "ec2_dynamo_profile" {
  name = "ec2-dynamodb-fullaccess-profile"
  role = aws_iam_role.ec2_dynamo_role.name
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.key-tf.key_name
  vpc_security_group_ids = ["${aws_security_group.allow_tls.id}"]
  subnet_id              = aws_subnet.public_a.id
  user_data              = templatefile("${path.module}/user_data.sh", {})
  iam_instance_profile   = aws_iam_instance_profile.ec2_dynamo_profile.name
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
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.key-tf.key_name
  vpc_security_group_ids = ["${aws_security_group.allow_tls.id}"]
  subnet_id              = aws_subnet.public_b.id
  user_data              = templatefile("${path.module}/user_data.sh", {})
  iam_instance_profile   = aws_iam_instance_profile.ec2_dynamo_profile.name
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

# ALB Security Group (allow HTTP from anywhere)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP inbound to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# Internet-facing ALB across public subnets
resource "aws_lb" "app_lb" {
  name               = "pastebin-app-lb"
  load_balancer_type = "application"
  internal           = false
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb_sg.id]
}

# Target group for backend on port 8000
resource "aws_lb_target_group" "app_tg" {
  name        = "pastebin-app-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
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

# Listener on port 80 -> target group
resource "aws_lb_listener" "http" {
  depends_on = [ aws_lb_target_group.app_tg ]
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Attach instance to target group
resource "aws_lb_target_group_attachment" "app_tg_attachment" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web.id
  port             = 8000
}

resource "aws_lb_target_group_attachment" "app_tg_attachment2" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.web2.id
  port             = 8000
}


#create dynamdb table
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

resource "aws_sqs_queue" "pastebin-backend-queue" {
  name                       = "pastebin-backend-queue"
  visibility_timeout_seconds = 30
}

###############################
# Lambda for SQS -> Polly -> S3
###############################

resource "aws_s3_bucket" "voice_output" {
  bucket_prefix = "pastebin-voice-output"
  force_destroy = true
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_voice_role" {
  name = "pastebin-voice-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_voice_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_voice_access" {
  name        = "pastebin-voice-access"
  description = "Allow Polly synth and S3 put for voice outputs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "PollySynthesize",
        Effect = "Allow",
        Action = [
          "polly:SynthesizeSpeech"
        ],
        Resource = "*"
      },
      {
        Sid    = "S3PutVoice",
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ],
        Resource = [
          aws_s3_bucket.voice_output.arn,
          "${aws_s3_bucket.voice_output.arn}/*"
        ]
      },
      {
        Sid    = "SQSPollAccess",
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility"
        ],
        Resource = aws_sqs_queue.pastebin-backend-queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_voice_access_attach" {
  role       = aws_iam_role.lambda_voice_role.name
  policy_arn = aws_iam_policy.lambda_voice_access.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"

  source {
    content  = file("${path.module}/../pastebin-voice/function.py")
    filename = "function.py"
  }
}

resource "aws_lambda_function" "voice_worker" {
  function_name = "pastebin-voice-worker"
  role          = aws_iam_role.lambda_voice_role.arn
  handler       = "function.handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout       = 30

  environment {
    variables = {
      S3_BUCKET  = aws_s3_bucket.voice_output.bucket
      POLLY_VOICE = "Joanna"
      POLLY_ENGINE = "neural"
    }
  }
}

resource "aws_lambda_event_source_mapping" "sqs_to_voice_lambda" {
  event_source_arn = aws_sqs_queue.pastebin-backend-queue.arn
  function_name    = aws_lambda_function.voice_worker.arn
  batch_size       = 5
  enabled          = true
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}
