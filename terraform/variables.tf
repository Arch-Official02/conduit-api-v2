variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "conduit"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ecr_repo_url" {
  description = "ECR repository URL"
  type        = string
}

variable "mongodb_uri" {
  description = "MongoDB connection string"
  type        = string
  sensitive   = true
}

variable "secret" {
  description = "JWT secret for the app"
  type        = string
  sensitive   = true
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = "conduit-key"
}
