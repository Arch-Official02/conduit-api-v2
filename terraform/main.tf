terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── VPC module ────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

# ── Security groups module ────────────────────────────────────────────────────
module "security_groups" {
  source = "./modules/security-groups"

  project_name = var.project_name
  vpc_id       = module.vpc.vpc_id
}

# ── ALB module ────────────────────────────────────────────────────────────────
module "alb" {
  source = "./modules/alb"

  project_name      = var.project_name
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  vpc_id            = module.vpc.vpc_id
}

# ── EC2 module ────────────────────────────────────────────────────────────────
module "ec2" {
  source = "./modules/ec2"

  project_name         = var.project_name
  public_subnet_id     = module.vpc.public_subnet_ids[0]
  ec2_sg_id            = module.security_groups.ec2_sg_id
  alb_target_group_arn = module.alb.target_group_arn
  ecr_repo_url         = var.ecr_repo_url
  mongodb_uri          = var.mongodb_uri
  secret               = var.secret
  aws_region           = var.aws_region
  key_name             = var.key_name
}
