variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_a" {
  type    = string
  default = "us-east-1a"
}

variable "az_b" {
  type    = string
  default = "us-east-1b"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "pastebin-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "pastebin-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-route-table" }
}

resource "aws_subnet" "pastebin_az_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.az_a
  map_public_ip_on_launch = true
  tags = { Name = "pastebin-az-a" }
}

resource "aws_subnet" "pastebin_az_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.az_b
  map_public_ip_on_launch = true
  tags = { Name = "pastebin-az-b" }
}

resource "aws_route_table_association" "a_public" {
  subnet_id      = aws_subnet.pastebin_az_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "b_public" {
  subnet_id      = aws_subnet.pastebin_az_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "allow_tls" {
  name        = "pastebin-backend-ec2"
  description = "Allow TLS inbound traffic on port 8000 from anythere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "TLS from anywhere"
    from_port        = 8000
    to_port          = 8000
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

  tags = { Name = "pastebin-backend-sg" }
}

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
  subnets            = [aws_subnet.pastebin_az_a.id, aws_subnet.pastebin_az_b.id]
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
  depends_on        = [aws_lb_target_group.app_tg]
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_a_id" { value = aws_subnet.pastebin_az_a.id }
output "public_subnet_b_id" { value = aws_subnet.pastebin_az_b.id}
output "ec2_sg_id" { value = aws_security_group.allow_tls.id }
output "alb_sg_id" { value = aws_security_group.alb_sg.id }
output "backend_tg_id" {value = aws_lb_target_group.app_tg.arn}
