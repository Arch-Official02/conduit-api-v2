# ── IAM Role for EC2 ──────────────────────────────────────────────────────────
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ── Get latest Amazon Linux 2 AMI ─────────────────────────────────────────────
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ── EC2 Instance ──────────────────────────────────────────────────────────────
resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.small"
  subnet_id                   = var.public_subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [var.ec2_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  key_name                    = var.key_name

  user_data = templatefile("${path.module}/userdata.sh", {
    aws_region   = var.aws_region
    ecr_repo_url = var.ecr_repo_url
    secret       = var.secret
  })

  tags = {
    Name = "${var.project_name}-app-server"
  }
}

# ── Register EC2 with ALB target group ────────────────────────────────────────
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = var.alb_target_group_arn
  target_id        = aws_instance.app.id
  port             = 3000
}
