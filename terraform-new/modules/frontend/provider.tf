provider "aws" {
  region = "us-west-2"  # Your primary region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"  # Required for CloudFront WAF integration
}

#CloudFront is a global service, and AWS requires that any WAF Web ACL associated with a CloudFront distribution be created in the us-east-1 region. Even if your other resources (like S3 or other parts of your infrastructure) are in a single region, the WAF resource for CloudFront must be provisioned in us-east-1. This is why the provider alias is used: it allows you to explicitly direct Terraform to create the WAF resource in us-east-1 while your other resources can reside in your primary region.