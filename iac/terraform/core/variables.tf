variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "materclaims-cluster"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_1_cidr" {
  description = "CIDR block for public subnet 1"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for public subnet 2"
  type        = string
  default     = "10.0.2.0/24"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for state store"
  type        = string
  default     = "claims"
}

variable "attach_security_services_policy_to_current_user" {
  description = "Whether to attach Inspector/Security Hub permissions to the current IAM user"
  type        = bool
  default     = false
}

variable "config_bucket_name" {
  description = "S3 bucket name for AWS Config snapshots (defaults to the Terraform backend bucket)"
  type        = string
  default     = ""
}
