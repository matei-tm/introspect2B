# Intelligent Autoscaling Controller

An AI-workload-aware autoscaling solution designed specifically for claims processing workloads that rely on Amazon Bedrock for GenAI inference.

## Overview

Traditional autoscaling (HPA/VPA) reacts to CPU and memory metrics, which don't tell the full story for AI-assisted workloads. This intelligent controller:

- **Understands AI workload behavior** - Accounts for variable Bedrock inference latency
- **Correlates multiple signals** - CPU, memory, API latency, and Bedrock duration
- **Filters noise** - Ignores transient spikes from model loading or caching
- **Provides proactive scaling** - Trend analysis prevents bottlenecks before they occur
- **Explains decisions** - Full audit trail of why scaling actions were taken

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CloudWatch Metrics                            │
│  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌────────────────┐ │
│  │   CPU    │  │  Memory   │  │ Latency  │  │ Bedrock Infer. ││ │
│  └────┬─────┘  └─────┬─────┘  └────┬─────┘  └────────┬───────┘ │
└───────┼──────────────┼─────────────┼─────────────────┼─────────┘
        │              │             │                 │
        └──────────────┴─────────────┴─────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │                    │
                    │  Lambda Function   │
                    │  (Every 5 minutes) │
                    │                    │
                    └─────────┬──────────┘
                              │
            ┌─────────────────┼─────────────────┐
            │                 │                 │
     ┌──────▼──────┐   ┌──────▼──────┐  ┌──────▼──────┐
     │ Trend       │   │ Noise       │  │ Decision    │
     │ Analysis    │   │ Filter      │  │ Engine      │
     └──────┬──────┘   └──────┬──────┘  └──────┬──────┘
            │                 │                 │
            └─────────────────┴─────────────────┘
                              │
                    ┌─────────▼──────────┐
                    │                    │
                    │  Scaling Decision  │
                    │  (logged & metered)│
                    │                    │
                    └────────────────────┘
```

## Key Features

### 1. Multi-Metric Evaluation

Instead of relying on a single metric, the controller evaluates:

- **CPU Utilization** - Standard compute load
- **Memory Usage** - Container memory pressure
- **API Latency** - End-to-end request duration (including Bedrock calls)
- **Bedrock Inference Duration** - AI model invocation time

### 2. Trend-Based Forecasting

Uses linear regression to detect:
- **Increasing trends** - Proactive scale-up before thresholds are hit
- **Decreasing trends** - Safe scale-down opportunities
- **Stable patterns** - No action needed

Configurable threshold (default 15% change = trend).

### 3. Intelligent Noise Filtering

Filters out transient spikes caused by:
- Cold starts and initialization
- Model loading/caching
- Single slow requests
- Network blips

Uses coefficient of variation to distinguish signal from noise (default 5% threshold).

### 4. Dual Trigger Model

**Proactive Mode** (Every 5 minutes via EventBridge):
- Evaluates combined trends
- Enables early scaling to prevent bottlenecks
- Gradual, predictable scaling behavior

**Reactive Mode** (CloudWatch Alarms):
- Triggers on hard thresholds:
  - API latency > 5 seconds
  - Bedrock inference > 4 seconds
- Immediate response to urgent conditions

### 5. Explainable Decisions

Every scaling action includes:
- Metrics that triggered it
- Trend analysis results
- Reasoning for the decision
- Mode (proactive vs reactive)

Example decision log:
```json
{
  "decision": "scale_up",
  "mode": "proactive",
  "reasoning": [
    "Multi-metric evaluation: 3 scale-up signals detected",
    "CPU: High utilization (75%) with increasing trend",
    "API Latency: Sustained high latency (5200ms) with increasing trend",
    "Bedrock: Inference duration (3800ms) increasing, likely due to concurrency limits"
  ],
  "metrics_evaluated": {
    "cpu": {
      "current": 75,
      "trend": "increasing",
      "magnitude": 0.18,
      "is_signal": true
    },
    "latency": {
      "current": 5200,
      "trend": "increasing", 
      "magnitude": 0.22,
      "is_signal": true
    },
    "bedrock": {
      "current": 3800,
      "trend": "increasing",
      "magnitude": 0.15,
      "is_signal": true
    }
  },
  "timestamp": "2026-02-14T10:35:00Z"
}
```

## Configuration

Environment variables (set in Terraform):

```bash
EKS_CLUSTER_NAME=introspect2b-eks          # EKS cluster name
NAMESPACE=materclaims                       # Kubernetes namespace
DEPLOYMENT_NAME=claim-status-api            # Deployment to monitor
MIN_REPLICAS=2                              # Minimum pod count
MAX_REPLICAS=10                             # Maximum pod count
METRIC_WINDOW_MINUTES=10                    # Lookback window for trends
TREND_THRESHOLD=0.15                        # 15% change = trend
NOISE_FILTER_THRESHOLD=0.05                 # 5% variation = noise
```

## Deployment

Deployed automatically via Terraform:

```bash
cd iac/terraform
terraform apply
```

This creates:
- Lambda function with Python 3.11 runtime
- IAM role with CloudWatch and EKS permissions
- EventBridge rule (every 5 minutes)
- CloudWatch alarms for reactive triggers
- CloudWatch dashboard for observability

## Monitoring

### CloudWatch Dashboard

Access the dashboard at:
```
AWS Console → CloudWatch → Dashboards → introspect2b-eks-intelligent-autoscaler
```

**Widgets:**
1. **Autoscaler Performance** - Execution success/failure, scaling decisions
2. **Pod Resource Utilization** - CPU/Memory trends
3. **API and AI Performance** - API latency, Bedrock inference duration
4. **Recent Scaling Decisions** - Log query showing decision reasoning

### Metrics Published

**Namespace:** `IntelligentAutoscaler`

- `ScalingDecision` - 1 (scale up), -1 (scale down), 0 (no action)
- `ExecutionSuccess` - 1 (success), 0 (failure)
- `ExecutionFailure` - Count of failures

**Dimensions:**
- ClusterName
- Namespace
- Deployment

### Logs

View detailed decision logs:
```bash
aws logs tail /aws/lambda/introspect2b-eks-intelligent-autoscaler --follow
```

Filter for scaling actions:
```bash
aws logs tail /aws/lambda/introspect2b-eks-intelligent-autoscaler \
  --follow \
  --filter-pattern '{ $.decision.action != "none" }'
```

## Integration with HPA/VPA

This controller **complements** (not replaces) HPA and VPA:

### With HPA
- HPA handles immediate reactive scaling based on CPU/memory
- Intelligent controller provides context-aware, multi-metric decisions
- Both can coexist - HPA for fast response, intelligent controller for smarter decisions

### With VPA
- VPA optimizes pod resource requests/limits
- Intelligent controller focuses on replica count
- VPA in "Initial" mode ensures no conflicts

## Tuning

### Increasing Sensitivity
Make the controller more aggressive:
```hcl
TREND_THRESHOLD=0.10           # Trigger on 10% change instead of 15%
NOISE_FILTER_THRESHOLD=0.03    # Lower noise threshold
```

### Decreasing Sensitivity
Make the controller more conservative:
```hcl
TREND_THRESHOLD=0.20           # Require 20% change to trigger
NOISE_FILTER_THRESHOLD=0.10    # Higher noise threshold
```

### Adjusting Evaluation Window
```hcl
METRIC_WINDOW_MINUTES=15       # Longer window = smoother trends
METRIC_WINDOW_MINUTES=5        # Shorter window = faster response
```

## Troubleshooting

### Controller not scaling

**Check Lambda execution:**
```bash
aws logs tail /aws/lambda/introspect2b-eks-intelligent-autoscaler --since 10m
```

**Verify metrics are being collected:**
```bash
aws cloudwatch get-metric-statistics \
  --namespace ContainerInsights \
  --metric-name pod_cpu_utilization \
  --dimensions Name=ClusterName,Value=introspect2b-eks Name=Namespace,Value=materclaims \
  --start-time 2026-02-14T10:00:00Z \
  --end-time 2026-02-14T11:00:00Z \
  --period 60 \
  --statistics Average
```

### All signals filtered as noise

Lower the noise threshold:
```hcl
NOISE_FILTER_THRESHOLD=0.02
```

### Too many scaling actions

Increase thresholds:
```hcl
TREND_THRESHOLD=0.25
```

## Cost Optimization

**Lambda costs:**
- Triggered every 5 minutes = 288 invocations/day
- ~5s execution time, 256MB memory
- Estimated cost: ~$0.10/month (with AWS Free Tier)

**CloudWatch costs:**
- Custom metrics: ~$0.30/month per metric
- Log ingestion: ~$0.50/month
- Dashboard: Free (up to 3 dashboards)

**Total estimated cost:** ~$2-3/month

## Future Enhancements

Planned improvements:
1. **Direct K8s API integration** - Update HPA min/max dynamically
2. **Machine learning** - Use historical patterns for better forecasting
3. **Cost-aware scaling** - Factor in EC2 instance pricing
4. **Multi-cluster support** - Coordinate scaling across clusters
5. **Slack/Teams notifications** - Alert on significant scaling events

## References

- [AI Autoscaling Instructions](../../docs/ai-autoscaling.instructions.md)
- [HPA Documentation](../claim-status-api/k8s/AUTOSCALING.md)
- [CloudWatch Container Insights](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/ContainerInsights.html)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
