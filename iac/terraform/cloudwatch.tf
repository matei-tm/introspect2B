# CloudWatch Container Insights Configuration
# Note: EKS cluster logging is configured in eks.tf via cluster_enabled_log_types

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
      kubectl annotate serviceaccount cloudwatch-agent \
        -n amazon-cloudwatch \
        eks.amazonaws.com/role-arn=${aws_iam_role.cloudwatch_agent.arn} \
        --overwrite
    EOT
  }

  depends_on = [
    data.kubernetes_service_account.cloudwatch_agent,
    null_resource.update_kubeconfig
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
      kubectl annotate serviceaccount fluent-bit \
        -n amazon-cloudwatch \
        eks.amazonaws.com/role-arn=${aws_iam_role.fluent_bit.arn} \
        --overwrite
    EOT
  }

  depends_on = [
    data.kubernetes_service_account.fluent_bit,
    null_resource.update_kubeconfig
  ]

  triggers = {
    role_arn = aws_iam_role.fluent_bit.arn
  }
}

# Apply RBAC using kubectl to avoid authorization issues
resource "null_resource" "cloudwatch_rbac" {
  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f - <<EOF
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: cloudwatch-agent-role
      rules:
      - apiGroups: [""]
        resources: ["nodes", "nodes/proxy", "nodes/stats", "services", "endpoints", "pods", "configmaps", "namespaces"]
        verbs: ["get", "list", "watch", "create", "update"]
      - apiGroups: ["apps"]
        resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["batch"]
        resources: ["jobs", "cronjobs"]
        verbs: ["get", "list", "watch"]
      - apiGroups: ["discovery.k8s.io"]
        resources: ["endpointslices"]
        verbs: ["get", "list", "watch"]
      - apiGroups: [""]
        resources: ["nodes/metrics"]
        verbs: ["get"]
      - nonResourceURLs: ["/metrics"]
        verbs: ["get"]
      ---
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: cloudwatch-agent-role-binding
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: cloudwatch-agent-role
      subjects:
      - kind: ServiceAccount
        name: cloudwatch-agent
        namespace: amazon-cloudwatch
      ---
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRole
      metadata:
        name: fluent-bit-role
      rules:
      - apiGroups: [""]
        resources: ["namespaces", "pods", "pods/logs"]
        verbs: ["get", "list", "watch"]
      ---
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata:
        name: fluent-bit-role-binding
      roleRef:
        apiGroup: rbac.authorization.k8s.io
        kind: ClusterRole
        name: fluent-bit-role
      subjects:
      - kind: ServiceAccount
        name: fluent-bit
        namespace: amazon-cloudwatch
      EOF
    EOT
  }

  depends_on = [
    null_resource.update_kubeconfig
  ]

  triggers = {
    manifest_sha = sha256(<<-EOT
      CloudWatch RBAC manifest
    EOT
    )
  }
}

# ConfigMap for CloudWatch Agent
resource "kubernetes_config_map" "cloudwatch_agent" {
  metadata {
    name      = "cwagentconfig"
    namespace = data.kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }

  data = {
    "cwagentconfig.json" = jsonencode({
      logs = {
        metrics_collected = {
          kubernetes = {
            cluster_name                = var.cluster_name
            metrics_collection_interval = 60
          }
        }
        force_flush_interval = 5
      }
    })
  }

  depends_on = [data.kubernetes_namespace.amazon_cloudwatch]
}

# Reference ConfigMap for Fluent Bit (created by addon)
data "kubernetes_config_map" "fluent_bit_config" {
  metadata {
    name      = "fluent-bit-config"
    namespace = data.kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }

  depends_on = [data.kubernetes_namespace.amazon_cloudwatch]
}

# DaemonSet for CloudWatch Agent
resource "kubernetes_daemonset" "cloudwatch_agent" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = data.kubernetes_namespace.amazon_cloudwatch.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        name = "cloudwatch-agent"
      }
    }

    template {
      metadata {
        labels = {
          name = "cloudwatch-agent"
        }
      }

      spec {
        service_account_name = data.kubernetes_service_account.cloudwatch_agent.metadata[0].name

        container {
          name  = "cloudwatch-agent"
          image = "public.ecr.aws/cloudwatch-agent/cloudwatch-agent:latest"

          resources {
            limits = {
              cpu    = "200m"
              memory = "200Mi"
            }
            requests = {
              cpu    = "200m"
              memory = "200Mi"
            }
          }

          env {
            name = "HOST_IP"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "HOST_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "K8S_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          volume_mount {
            name       = "cwagentconfig"
            mount_path = "/etc/cwagentconfig"
          }

          volume_mount {
            name       = "rootfs"
            mount_path = "/rootfs"
            read_only  = true
          }

          volume_mount {
            name       = "dockersock"
            mount_path = "/var/run/docker.sock"
            read_only  = true
          }

          volume_mount {
            name       = "varlibdocker"
            mount_path = "/var/lib/docker"
            read_only  = true
          }

          volume_mount {
            name       = "sys"
            mount_path = "/sys"
            read_only  = true
          }

          volume_mount {
            name       = "devdisk"
            mount_path = "/dev/disk"
            read_only  = true
          }
        }

        volume {
          name = "cwagentconfig"
          config_map {
            name = kubernetes_config_map.cloudwatch_agent.metadata[0].name
          }
        }

        volume {
          name = "rootfs"
          host_path {
            path = "/"
          }
        }

        volume {
          name = "dockersock"
          host_path {
            path = "/var/run/docker.sock"
          }
        }

        volume {
          name = "varlibdocker"
          host_path {
            path = "/var/lib/docker"
          }
        }

        volume {
          name = "sys"
          host_path {
            path = "/sys"
          }
        }

        volume {
          name = "devdisk"
          host_path {
            path = "/dev/disk"
          }
        }

        termination_grace_period_seconds = 60
      }
    }
  }

  depends_on = [
    data.kubernetes_service_account.cloudwatch_agent,
    kubernetes_config_map.cloudwatch_agent
  ]
}

# DaemonSet for Fluent Bit
resource "kubernetes_daemonset" "fluent_bit" {
  metadata {
    name      = "fluent-bit"
    namespace = data.kubernetes_namespace.amazon_cloudwatch.metadata[0].name
    labels = {
      k8s-app                         = "fluent-bit"
      version                         = "v1"
      "kubernetes.io/cluster-service" = "true"
    }
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "fluent-bit"
      }
    }

    template {
      metadata {
        labels = {
          k8s-app                         = "fluent-bit"
          version                         = "v1"
          "kubernetes.io/cluster-service" = "true"
        }
      }

      spec {
        service_account_name = data.kubernetes_service_account.fluent_bit.metadata[0].name

        container {
          name  = "fluent-bit"
          image = "public.ecr.aws/aws-observability/aws-for-fluent-bit:latest"

          resources {
            limits = {
              memory = "200Mi"
            }
            requests = {
              cpu    = "500m"
              memory = "100Mi"
            }
          }

          volume_mount {
            name       = "fluentbitstate"
            mount_path = "/var/fluent-bit/state"
          }

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
            read_only  = true
          }

          volume_mount {
            name       = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only  = true
          }

          volume_mount {
            name       = "fluent-bit-config"
            mount_path = "/fluent-bit/etc/"
          }
        }

        volume {
          name = "fluentbitstate"
          host_path {
            path = "/var/fluent-bit/state"
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }

        volume {
          name = "fluent-bit-config"
          config_map {
            name = kubernetes_config_map.fluent_bit_config.metadata[0].name
          }
        }

        termination_grace_period_seconds = 10
      }
    }
  }

  depends_on = [
    data.kubernetes_service_account.fluent_bit,
    data.kubernetes_config_map.fluent_bit_config
  ]
}
