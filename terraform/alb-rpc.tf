# Terraform configuration for Flora RPC Load Balancer
# This sets up an AWS ALB to load balance RPC traffic across all Flora nodes

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-1"
}

# Variables
variable "vpc_id" {
  description = "VPC ID where Flora nodes are running"
  type        = string
}

variable "subnet_ids" {
  description = "Public subnet IDs for ALB (must be in at least 2 AZs)"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for rpc.flora.network"
  type        = string
}

# Security Group for ALB
resource "aws_security_group" "flora_rpc_alb" {
  name        = "flora-rpc-alb-sg"
  description = "Security group for Flora RPC ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "flora-rpc-alb-sg"
  }
}

# Target Group for RPC nodes
resource "aws_lb_target_group" "flora_rpc" {
  name     = "flora-rpc-tg"
  port     = 8545
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-499"  # JSON-RPC returns various codes
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400  # 24 hours
    enabled         = true
  }

  tags = {
    Name = "flora-rpc-tg"
  }
}

# Register Flora nodes as targets
resource "aws_lb_target_group_attachment" "flora_node_1" {
  target_group_arn = aws_lb_target_group.flora_rpc.arn
  target_id        = "52.9.17.25"
  port             = 8545
}

resource "aws_lb_target_group_attachment" "flora_node_2" {
  target_group_arn = aws_lb_target_group.flora_rpc.arn
  target_id        = "50.18.34.12"
  port             = 8545
}

resource "aws_lb_target_group_attachment" "flora_node_3" {
  target_group_arn = aws_lb_target_group.flora_rpc.arn
  target_id        = "204.236.162.240"
  port             = 8545
}

# Application Load Balancer
resource "aws_lb" "flora_rpc" {
  name               = "flora-rpc-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.flora_rpc_alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false
  enable_http2              = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "flora-rpc-alb"
  }
}

# HTTP listener (redirect to HTTPS)
resource "aws_lb_listener" "flora_rpc_http" {
  load_balancer_arn = aws_lb.flora_rpc.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener
resource "aws_lb_listener" "flora_rpc_https" {
  load_balancer_arn = aws_lb.flora_rpc.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flora_rpc.arn
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "unhealthy_targets" {
  alarm_name          = "flora-rpc-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy Flora RPC targets"
  treat_missing_data  = "notBreaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.flora_rpc.arn_suffix
    LoadBalancer = aws_lb.flora_rpc.arn_suffix
  }
}

# Outputs
output "alb_dns_name" {
  description = "DNS name of the load balancer - add this as CNAME for rpc.flora.network"
  value       = aws_lb.flora_rpc.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.flora_rpc.arn
}