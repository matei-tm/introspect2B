# CloudWatch Container Insights Configuration
# Note: The amazon-cloudwatch-observability EKS addon (configured in eks.tf) automatically creates:
# - Namespace: amazon-cloudwatch
# - ServiceAccounts: cloudwatch-agent, fluent-bit  
# - DaemonSets: cloudwatch-agent, fluent-bit
# - ConfigMaps for both agents
# - RBAC (ClusterRoles, ClusterRoleBindings)
#
# This file only manages:
# - IAM roles and policies for IRSA (IAM Roles for Service Accounts)
# - Patching service accounts with IAM role annotations
# - CloudWatch Log Groups for Container Insights

# CloudWatch Log Groups for Container Insights
resource "aws_cloudwatch_log_group" "container_insights_application" {
  name              = "/aws/containerinsights/${var.cluster_name}/application"
  retention_in_days = 7

  tags = {
    Name        = "EKS Container Insights Application Logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "container_insights_performance" {
  name              = "/aws/containerinsights/${var.cluster_name}/performance"
  retention_in_days = 7

  tags = {
    Name        = "EKS Container Insights Performance Logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "container_insights_dataplane" {
  name              = "/aws/containerinsights/${var.cluster_name}/dataplane"
  retention_in_days = 7

  tags = {
    Name        = "EKS Container Insights Dataplane Logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "container_insights_host" {
  name              = "/aws/containerinsights/${var.cluster_name}/host"
  retention_in_days = 7

  tags = {
    Name        = "EKS Container Insights Host Logs"
    Environment = var.environment
  }
}

# IAM Policy for CloudWatch Container Insights
data "aws_iam_policy_document" "cloudwatch_container_insights" {
  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeVolumes",
      "ec2:DescribeTags",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloudwatch_container_insights" {
  name        = "CloudWatchContainerInsightsPolicy"
  description = "Policy for CloudWatch Container Insights"
  policy      = data.aws_iam_policy_document.cloudwatch_container_insights.json

  tags = {
    Name = "CloudWatchContainerInsightsPolicy"
  }
}

# IAM Role for CloudWatch agent
resource "aws_iam_role" "cloudwatch_agent" {
  name = "CloudWatchAgentRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "CloudWatchAgentRole"
  }

  depends_on = [module.eks]
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  policy_arn = aws_iam_policy.cloudwatch_container_insights.arn
  role       = aws_iam_role.cloudwatch_agent.name
}

# Attach AWS managed policy for CloudWatch agent
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_server_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cloudwatch_agent.name
}

# IAM Role for Fluent Bit
resource "aws_iam_role" "fluent_bit" {
  name = "FluentBitRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:amazon-cloudwatch:fluent-bit"
            "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "FluentBitRole"
  }

  depends_on = [module.eks]
}

resource "aws_iam_role_policy_attachment" "fluent_bit" {
  policy_arn = aws_iam_policy.cloudwatch_container_insights.arn
  role       = aws_iam_role.fluent_bit.name
}

# Reference the Kubernetes Namespace created by amazon-cloudwatch-observability addon
data "kubernetes_namespace" "amazon_cloudwatch" {
  metadata {
    name = "amazon-cloudwatch"
  }

  depends_on = [
    module.eks,
    null_resource.update_kubeconfig,
    time_sleep.wait_for_access_policy
  ]
}

# Patch CloudWatch Agent Service Account with IRSA annotation
resource "null_resource" "patch_cloudwatch_agent_sa" {
  provisioner "local-exec" {
    command = <<-EOT
      # Update kubeconfig to ensure kubectl has access
      aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}
      
      # Wait for addon to create service account
      sleep 15
      
      # Wait for service account to be created by addon
      for i in {1..30}; do
        if kubectl get serviceaccount cloudwatch-agent -n amazon-cloudwatch 2>/dev/null; then
          echo "Service account found"
          break
        fi
        echo "Waiting for service account... attempt $i/30"
        sleep 2
      done
      
      # Patch service account with IRSA annotation
      kubectl annotate serviceaccount cloudwatch-agent \
        -n amazon-cloudwatch \
        eks.amazonaws.com/role-arn=${aws_iam_role.cloudwatch_agent.arn} \
        --overwrite
    EOT
  }

  depends_on = [
    data.kubernetes_namespace.amazon_cloudwatch,
    null_resource.update_kubeconfig,
    time_sleep.wait_for_access_policy
  ]

  triggers = {
    role_arn = aws_iam_role.cloudwatch_agent.arn
  }
}

# Note: Fluent Bit service account is NOT created by the EKS CloudWatch Observability addon
# The fluent-bit pods use the 'cloudwatch-agent' service account for IRSA
# Therefore, no separate fluent-bit service account patching is needed
# The FluentBitRole IAM role is kept for potential future use or manual configuration
