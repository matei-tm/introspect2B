# Intelligent Autoscaling Lambda for AI Workloads
# Implements context-aware, multi-metric scaling decisions

# IAM Role for Lambda
resource "aws_iam_role" "intelligent_autoscaler" {
  name = "${var.cluster_name}-intelligent-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "IntelligentAutoscalerRole"
  }
}

# IAM Policy for Lambda
resource "aws_iam_policy" "intelligent_autoscaler" {
  name        = "${var.cluster_name}-intelligent-autoscaler-policy"
  description = "Policy for intelligent autoscaler Lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:SetDesiredCapacity"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name = "IntelligentAutoscalerPolicy"
  }
}

resource "aws_iam_role_policy_attachment" "intelligent_autoscaler" {
  role       = aws_iam_role.intelligent_autoscaler.name
  policy_arn = aws_iam_policy.intelligent_autoscaler.arn
}

# Lambda function package
data "archive_file" "intelligent_autoscaler" {
  type        = "zip"
  source_dir  = "${path.module}/../../src/intelligent-autoscaler"
  output_path = "${path.module}/intelligent-autoscaler.zip"
}

# Lambda function
resource "aws_lambda_function" "intelligent_autoscaler" {
  filename         = data.archive_file.intelligent_autoscaler.output_path
  function_name    = "${var.cluster_name}-intelligent-autoscaler"
  role             = aws_iam_role.intelligent_autoscaler.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.intelligent_autoscaler.output_base64sha256
  runtime          = "python3.11"
  timeout          = 300 # 5 minutes
  memory_size      = 256

  environment {
    variables = {
      EKS_CLUSTER_NAME       = module.eks.cluster_name
      NAMESPACE              = "materclaims"
      DEPLOYMENT_NAME        = "claim-status-api"
      MIN_REPLICAS           = "2"
      MAX_REPLICAS           = "10"
      METRIC_WINDOW_MINUTES  = "10"
      TREND_THRESHOLD        = "0.15"
      NOISE_FILTER_THRESHOLD = "0.05"
    }
  }

  tags = {
    Name        = "IntelligentAutoscaler"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.intelligent_autoscaler,
    module.eks
  ]
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "intelligent_autoscaler" {
  name              = "/aws/lambda/${aws_lambda_function.intelligent_autoscaler.function_name}"
  retention_in_days = 7

  tags = {
    Name = "IntelligentAutoscalerLogs"
  }
}

# EventBridge Rule - Proactive Mode (every 5 minutes)
resource "aws_cloudwatch_event_rule" "intelligent_autoscaler_schedule" {
  name                = "${var.cluster_name}-autoscaler-schedule"
  description         = "Trigger intelligent autoscaler every 5 minutes for proactive scaling"
  schedule_expression = "rate(5 minutes)"

  tags = {
    Name = "IntelligentAutoscalerSchedule"
  }
}

resource "aws_cloudwatch_event_target" "intelligent_autoscaler_schedule" {
  rule      = aws_cloudwatch_event_rule.intelligent_autoscaler_schedule.name
  target_id = "IntelligentAutoscaler"
  arn       = aws_lambda_function.intelligent_autoscaler.arn
}

resource "aws_lambda_permission" "allow_eventbridge_schedule" {
  statement_id  = "AllowExecutionFromEventBridgeSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.intelligent_autoscaler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.intelligent_autoscaler_schedule.arn
}

# CloudWatch Alarms for Reactive Mode

# High API Latency Alarm
resource "aws_cloudwatch_metric_alarm" "api_latency_high" {
  alarm_name          = "${var.cluster_name}-api-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "APILatency"
  namespace           = "ClaimStatusAPI"
  period              = 60
  statistic           = "Average"
  threshold           = 5000 # 5 seconds
  alarm_description   = "API latency is consistently high"
  treat_missing_data  = "notBreaching"

  dimensions = {
    Service   = "claim-status-api"
    Namespace = "materclaims"
  }

  alarm_actions = [aws_lambda_function.intelligent_autoscaler.arn]

  tags = {
    Name = "APILatencyHighAlarm"
  }
}

resource "aws_lambda_permission" "allow_cloudwatch_api_latency" {
  statement_id  = "AllowExecutionFromCloudWatchAPILatency"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.intelligent_autoscaler.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.api_latency_high.arn
}

# High Bedrock Inference Duration Alarm
resource "aws_cloudwatch_metric_alarm" "bedrock_duration_high" {
  alarm_name          = "${var.cluster_name}-bedrock-duration-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "BedrockInferenceDuration"
  namespace           = "ClaimStatusAPI"
  period              = 60
  statistic           = "Average"
  threshold           = 4000 # 4 seconds
  alarm_description   = "Bedrock inference duration is high, indicating potential concurrency issues"
  treat_missing_data  = "notBreaching"

  dimensions = {
    Service = "claim-status-api"
    Model   = "claude-3-haiku"
  }

  alarm_actions = [aws_lambda_function.intelligent_autoscaler.arn]

  tags = {
    Name = "BedrockDurationHighAlarm"
  }
}

resource "aws_lambda_permission" "allow_cloudwatch_bedrock" {
  statement_id  = "AllowExecutionFromCloudWatchBedrock"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.intelligent_autoscaler.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.bedrock_duration_high.arn
}

# CloudWatch Dashboard for Intelligent Autoscaler
resource "aws_cloudwatch_dashboard" "intelligent_autoscaler" {
  dashboard_name = "${var.cluster_name}-intelligent-autoscaler"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          metrics = [
            ["IntelligentAutoscaler", "ScalingDecision", { stat = "Sum", label = "Scaling Decisions" }],
            [".", "ExecutionSuccess", { stat = "Sum", label = "Successful Executions" }],
            [".", "ExecutionFailure", { stat = "Sum", label = "Failed Executions" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Autoscaler Performance"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["ContainerInsights", "pod_cpu_utilization", { stat = "Average" }],
            [".", "pod_memory_utilization", { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "Pod Resource Utilization"
        }
      },
      {
        type = "metric"
        properties = {
          metrics = [
            ["ClaimStatusAPI", "APILatency", { stat = "Average" }],
            [".", "BedrockInferenceDuration", { stat = "Average" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "API and AI Performance"
        }
      },
      {
        type = "log"
        properties = {
          query  = "SOURCE '/aws/lambda/${aws_lambda_function.intelligent_autoscaler.function_name}' | fields @timestamp, decision.action, decision.mode, decision.reason | filter decision.action != 'none' | sort @timestamp desc"
          region = var.aws_region
          title  = "Recent Scaling Decisions"
        }
      }
    ]
  })
}

# Outputs
output "intelligent_autoscaler_function_name" {
  description = "Name of the intelligent autoscaler Lambda function"
  value       = aws_lambda_function.intelligent_autoscaler.function_name
}

output "intelligent_autoscaler_function_arn" {
  description = "ARN of the intelligent autoscaler Lambda function"
  value       = aws_lambda_function.intelligent_autoscaler.arn
}

output "intelligent_autoscaler_dashboard_url" {
  description = "URL to the intelligent autoscaler CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.intelligent_autoscaler.dashboard_name}"
}
