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

# Reference Service Account for CloudWatch Agent (created by addon)
data "kubernetes_service_account" "cloudwatch_agent" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = data.kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }

  depends_on = [data.kubernetes_namespace.amazon_cloudwatch]
}

# Patch CloudWatch Agent Service Account with IRSA annotation
resource "null_resource" "patch_cloudwatch_agent_sa" {
  provisioner "local-exec" {
    command = <<-EOT
      # Update kubeconfig to ensure kubectl has access
      aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}
      
      # Wait for addon to create service account
      sleep 10
      
      # Patch service account with IRSA annotation
      kubectl annotate serviceaccount cloudwatch-agent \
        -n amazon-cloudwatch \
        eks.amazonaws.com/role-arn=${aws_iam_role.cloudwatch_agent.arn} \
        --overwrite
    EOT
  }

  depends_on = [
    data.kubernetes_service_account.cloudwatch_agent,
    null_resource.update_kubeconfig,
    time_sleep.wait_for_access_policy
  ]

  triggers = {
    role_arn = aws_iam_role.cloudwatch_agent.arn
  }
}

# Reference Service Account for Fluent Bit (created by addon)
data "kubernetes_service_account" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = data.kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }

  depends_on = [data.kubernetes_namespace.amazon_cloudwatch]
}

# Patch Fluent Bit Service Account with IRSA annotation
resource "null_resource" "patch_fluent_bit_sa" {
  provisioner "local-exec" {
    command = <<-EOT
      # Update kubeconfig to ensure kubectl has access
      aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}
      
      # Wait for addon to create service account
      sleep 10
      
      # Patch service account with IRSA annotation
      kubectl annotate serviceaccount fluent-bit \
        -n amazon-cloudwatch \
        eks.amazonaws.com/role-arn=${aws_iam_role.fluent_bit.arn} \
        --overwrite
    EOT
  }

  depends_on = [
    data.kubernetes_service_account.fluent_bit,
    null_resource.update_kubeconfig,
    time_sleep.wait_for_access_policy
  ]

  triggers = {
    role_arn = aws_iam_role.fluent_bit.arn
  }
}
