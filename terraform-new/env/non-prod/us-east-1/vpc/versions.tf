terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


terraform {
  backend "s3" {
    bucket = "mybucket"
    encrypt = true
    key    = "terraform/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}
