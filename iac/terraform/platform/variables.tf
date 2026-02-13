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

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for EKS nodes"
  type        = string
  default     = "t3.medium"
}

variable "node_desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "namespace" {
  description = "Kubernetes namespace for applications"
  type        = string
  default     = "materclaims"
}

variable "ecr_repository_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = ["claim-status-api"]
}

variable "attach_ec2_policy_to_current_user" {
  description = "Whether to attach EC2InstanceTypeAccess policy to the current IAM user"
  type        = bool
  default     = true
}

variable "codepipeline_stack_name" {
  description = "Name of the CloudFormation stack containing the CodePipeline and CodeBuild roles"
  type        = string
  default     = "introspect2b-codepipeline-v2"
}

variable "vpc_id" {
  description = "VPC ID from the core module"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs from the core module"
  type        = list(string)
}

variable "claim_notes_bucket_arn" {
  description = "S3 bucket ARN for claim notes from the core module"
  type        = string
}
