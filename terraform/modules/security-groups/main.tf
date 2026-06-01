# ── ALB Security Group ────────────────────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Allow HTTP inbound traffic to ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# ── EC2 Security Group ────────────────────────────────────────────────────────
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2-sg"
  description = "Allow traffic from ALB and SSH"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "App port from ALB only"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

ingress {
  from_port   = 9090
  to_port     = 9090
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Prometheus"
}

ingress {
  from_port   = 3001
  to_port     = 3001
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Grafana"
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-ec2-sg"
  }
}
