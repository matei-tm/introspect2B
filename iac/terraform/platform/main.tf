terraform {
  required_version = ">= 1.0"

  # S3 backend for state management
  # Run ../backend-setup.sh us-east-1 first to create the S3 bucket and DynamoDB table
  backend "s3" {
    bucket         = "introspect2b-terraform-state-322230759107"
    key            = "platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "introspect2b-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
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

provider "kubernetes" {
  host                   = try(module.eks.cluster_endpoint, "")
  cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", try(module.eks.cluster_name, "")]
  }
}

provider "helm" {
  kubernetes {
    host                   = try(module.eks.cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", try(module.eks.cluster_name, "")]
    }
  }
}
