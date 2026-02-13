terraform {
  required_version = ">= 1.0"

  # S3 backend for state management
  # Run ../backend-setup.sh us-east-1 first to create the S3 bucket and DynamoDB table
  backend "s3" {
    bucket         = "introspect2b-terraform-state-322230759107"
    key            = "core/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "introspect2b-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "EKS-Dapr-Demo"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Get current caller identity
data "aws_caller_identity" "current" {}

locals {
  backend_bucket_name = "introspect2b-terraform-state-${data.aws_caller_identity.current.account_id}"
  config_bucket_name  = var.config_bucket_name != "" ? var.config_bucket_name : local.backend_bucket_name
}
