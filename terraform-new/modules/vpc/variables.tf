variable "name" {
  type        = string
  default     = ""
  description = "Name of the resources"
}

variable "environment" {
  type        = string
  default     = ""
  description = "Name of the environment"
}
variable "vpc_cidr" {
  type        = string
  default     = ""
  description = "IPV4 CIDR range for the vpc"
}

variable "private_subnets" {
  type        = list(any)
  default     = []
  description = "List of CIDRS for private subnets"
}

variable "public_subnets" {
  type        = list(any)
  default     = []
  description = "List of CIDRS for public subnets"
}

variable "database_subnets" {
  type        = list(any)
  default     = []
  description = "List of CIDRS for database subnets"
}

variable "additional_tags" {
  type = map(string)
  default = {
    manage-by = "terraform"
  }
  description = "Additional resource tags"
}


variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "Create NatGateway"
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "Create only one NATGateway"
}

variable "enable_ipv6" {
  type        = bool
  default     = false
  description = "Creates a IPV6 Block in the VPC"
}

variable "public_subnet_ipv6_prefixes" {
  type        = list(number)
  default     = [0, 1, 2]
  description = "Splits the IPv6 block as per public subnet requirements"
}

variable "private_subnet_ipv6_prefixes" {
  type        = list(number)
  default     = [3, 6, 9]
  description = "Splits the IPv6 block as per private subnet requirements"

}

variable "database_subnet_ipv6_prefixes" {
  type        = list(number)
  default     = [10, 11]
  description = "Splits the IPv6 block as per database subnet requirements"
}

variable "private_subnet_assign_ipv6_address_on_creation" {
  type        = bool
  default     = true
  description = "attaches ipv6 address range to private subnets"
}

variable "public_subnet_assign_ipv6_address_on_creation" {
  type        = bool
  default     = true
  description = "attaches ipv6 address range to public subnets"
}

variable "database_subnet_assign_ipv6_address_on_creation" {
  type        = bool
  default     = true
  description = "attaches ipv6 address range to database subnets"
}