variable "project_name" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "ec2_sg_id" {
  type = string
}

variable "alb_target_group_arn" {
  type = string
}

variable "ecr_repo_url" {
  type = string
}

variable "mongodb_uri" {
  type = string
}

variable "secret" {
  type      = string
  sensitive = true
}

variable "aws_region" {
  type = string
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name for SSH access"
}
