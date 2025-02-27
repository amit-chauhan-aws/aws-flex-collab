data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name     = "${var.name}-${var.environment}"
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = merge(
    var.additional_tags,
    {
      managed-by = "Terraform"
    },
  )
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = local.name
  cidr = local.vpc_cidr

  azs                = local.azs
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  database_subnets   = var.database_subnets
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  enable_ipv6        = var.enable_ipv6

  public_subnet_ipv6_prefixes                     = var.public_subnet_ipv6_prefixes
  public_subnet_assign_ipv6_address_on_creation   = var.public_subnet_assign_ipv6_address_on_creation
  private_subnet_ipv6_prefixes                    = var.private_subnet_ipv6_prefixes
  private_subnet_assign_ipv6_address_on_creation  = var.private_subnet_assign_ipv6_address_on_creation
  database_subnet_ipv6_prefixes                   = var.database_subnet_ipv6_prefixes
  database_subnet_assign_ipv6_address_on_creation = var.database_subnet_assign_ipv6_address_on_creation

  tags = local.tags
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "database_subnets" {
  value = module.vpc.database_subnets
}