variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "services" {
  description = "List of services with their configurations (name, image, container_port, desired_count)"
  type = list(object({
    name           = string
    image          = string
    container_port = number
    desired_count  = number
    memory         = number
    cpu            = number
    max_capacity   = number
    min_capacity   = number
  }))
}

variable "public_subnets" {
  description = "List of public subnet IDs for the load balancer"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of private subnet IDs for the ECS service"
  type        = list(string)
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "log_group_retention_in_days" {
  description = "Retention period for CloudWatch log groups in days"
  type        = number
  default     = 7
}

variable "alarms" {
  description = "Alarm thresholds for CPU, memory, and request error rates"
  type = object({
    cpu_high_threshold         = number
    memory_high_threshold      = number
    request_5xx_rate_threshold = number
  })
}

variable "secrets" {
  description = "List of secrets from AWS Secrets Manager to be accessed by ECS tasks"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}
