module "vpc" {
  source             = "../../../../modules/vpc"
  name               = var.name
  vpc_cidr           = var.vpc_cidr
  enable_nat_gateway = var.enable_nat_gateway
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  database_subnets   = var.database_subnets
  environment        = var.environment
  additional_tags    = var.additional_tags
}