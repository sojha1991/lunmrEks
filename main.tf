terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  private_subnet_ids = module.vpc.private_subnet_ids
  vpc_id            = module.vpc.vpc_id
  eks_version        = var.eks_version
  node_instance_types = var.node_instance_types
  key_name           = var.key_name
} 