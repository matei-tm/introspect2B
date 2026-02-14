# Intelligent Autoscaler - Quick Start Guide

## What You're Deploying

An AI-aware autoscaling Lambda that monitors your claim-status-api and makes intelligent scaling decisions based on:
- Pod CPU/Memory utilization
- API response latency
- Bedrock (Claude 3) inference duration

## Prerequisites

- Terraform ≥ 1.0
- AWS CLI configured
- EKS cluster deployed (via main Terraform)
- claim-status-api running in EKS

## 5-Minute Setup

### Step 1: Deploy with Terraform

The Lambda is included in the main Terraform configuration:

```bash
cd iac/terraform

# Deploy (or update existing deployment)
terraform apply
```

This creates:
- Lambda function (Python 3.11)
- IAM role with CloudWatch + EKS permissions
- EventBridge rule (triggers every 5 minutes)
- CloudWatch alarms for reactive triggers
- CloudWatch dashboard

### Step 2: Verify Deployment

Check Lambda function exists:
```bash
aws lambda get-function \
  --function-name introspect2b-eks-intelligent-autoscaler \
  --region us-east-1
```

Expected output:
```json
{
  "Configuration": {
    "FunctionName": "introspect2b-eks-intelligent-autoscaler",
    "Runtime": "python3.11",
    "Handler": "lambda_function.lambda_handler",
    "MemorySize": 256,
    "Timeout": 300
  }
}
```

Check EventBridge rule:
```bash
aws events list-rules \
  --name-prefix introspect2b-autoscaler \
  --region us-east-1
```

### Step 3: Monitor First Execution

Wait 5 minutes for the first scheduled trigger, then check logs:

```bash
# Tail logs in real-time
aws logs tail /aws/lambda/introspect2b-eks-intelligent-autoscaler --follow

# Or view last 10 minutes
aws logs tail /aws/lambda/introspect2b-eks-intelligent-autoscaler --since 10m
```

Expected output:
```
2026-02-14T10:35:00.123Z START RequestId: abc-123
2026-02-14T10:35:01.456Z Intelligent Autoscaler triggered in proactive mode
2026-02-14T10:35:04.789Z {
  "decision": "none",
  "mode": "proactive",
  "reasoning": [
    "No correlated signals detected for scaling action",
    "cpu: Filtered as noise (variation < 0.05)",
    "memory: Current 45% - stable trend"
  ]
}
2026-02-14T10:35:05.012Z END RequestId: abc-123
```

### Step 4: View Dashboard

Open CloudWatch console and navigate to the dashboard:

```
AWS Console → CloudWatch → Dashboards → introspect2b-eks-intelligent-autoscaler
```

Or use this direct URL (replace `REGION`):
```
https://console.aws.amazon.com/cloudwatch/home?region=REGION#dashboards:name=introspect2b-eks-intelligent-autoscaler
```

## Testing the Autoscaler

### Trigger a Load Test

Generate artificial load to trigger scaling:

```bash
# Run performance tests via CodePipeline
# This will increase API latency and Bedrock usage

# Or manually generate load with k6
cd src/claim-status-api.Performance.Tests
k6 run performance-test.js --vus 50 --duration 5m
```

### Watch for Scaling Decisions

Monitor Lambda logs for scaling actions:

```bash
# Filter for non-"none" decisions
aws logs filter-log-events \
  --log-group-name /aws/lambda/introspect2b-eks-intelligent-autoscaler \
  --filter-pattern '{ $.decision.action != "none" }' \
  --start-time $(date -u -d '30 minutes ago' +%s)000 \
  | jq -r '.events[].message' \
  | jq -s '.'
```

### Check Metrics

View scaling decision metrics:

```bash
aws cloudwatch get-metric-statistics \
  --namespace IntelligentAutoscaler \
  --metric-name ScalingDecision \
  --dimensions Name=ClusterName,Value=introspect2b-eks \
  --start-time $(date -u -d '1 hour ago' --iso-8601) \
  --end-time $(date -u --iso-8601) \
  --period 300 \
  --statistics Sum
```

Result:
- `1` = Scale up decision
- `-1` = Scale down decision
- `0` = No action

## Configuration Tuning

The default configuration is optimized for AI workloads. To adjust:

### Make More Aggressive

Edit `iac/terraform/lambda-autoscaler.tf`:

```hcl
environment {
  variables = {
    TREND_THRESHOLD        = "0.10"  # Trigger on 10% change (default: 0.15)
    NOISE_FILTER_THRESHOLD = "0.03"  # Lower noise tolerance (default: 0.05)
    METRIC_WINDOW_MINUTES  = "5"     # Shorter evaluation window (default: 10)
  }
}
```

Apply changes:
```bash
terraform apply
```

### Make More Conservative

```hcl
environment {
  variables = {
    TREND_THRESHOLD        = "0.25"  # Require 25% change
    NOISE_FILTER_THRESHOLD = "0.10"  # Higher noise tolerance
    METRIC_WINDOW_MINUTES  = "15"    # Longer evaluation window
  }
}
```

## Troubleshooting

### Lambda Not Triggering

**Check EventBridge rule:**
```bash
aws events describe-rule --name introspect2b-eks-autoscaler-schedule
```

**Verify Lambda has permission:**
```bash
aws lambda get-policy \
  --function-name introspect2b-eks-intelligent-autoscaler \
  | jq '.Policy | fromjson'
```

Should include EventBridge as allowed principal.

### No Metrics in CloudWatch

**Publish test metric manually:**
```bash
aws cloudwatch put-metric-data \
  --namespace ClaimStatusAPI \
  --metric-name APILatency \
  --value 1500 \
  --dimensions Service=claim-status-api,Namespace=materclaims
```

**Check if metrics exist:**
```bash
aws cloudwatch list-metrics --namespace ClaimStatusAPI
```

### Lambda Errors

**View error logs:**
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/introspect2b-eks-intelligent-autoscaler \
  --filter-pattern ERROR \
  --since 1h
```

**Common issues:**
- Missing IAM permissions → Check `aws iam get-role-policy`
- Invalid metric names → Verify namespace and dimension names match Kubernetes resources
- Timeout (>5 min) → Increase Lambda timeout in Terraform

### All Signals Filtered as Noise

**Check metric variation:**
```bash
# View raw metric data
aws cloudwatch get-metric-statistics \
  --namespace ContainerInsights \
  --metric-name pod_cpu_utilization \
  --dimensions Name=ClusterName,Value=introspect2b-eks Name=Namespace,Value=materclaims \
  --start-time $(date -u -d '15 minutes ago' --iso-8601) \
  --end-time $(date -u --iso-8601) \
  --period 60 \
  --statistics Average
```

If values are very stable (e.g., all around 30%), that's working as designed - no scaling needed.

**To force action (for testing):**
Lower the noise threshold temporarily:
```hcl
NOISE_FILTER_THRESHOLD = "0.01"  # Very sensitive
```

## Cost Estimate

Monthly costs for intelligent autoscaler:

| Component | Usage | Cost |
|-----------|-------|------|
| Lambda invocations | 8,640/month (every 5 min) | $0.10 |
| Lambda duration | ~43,200 seconds/month | $0.00 (free tier) |
| CloudWatch custom metrics | 4 metrics | $1.20 |
| CloudWatch alarms | 2 alarms | $0.20 |
| CloudWatch log storage | ~500 MB/month | $0.50 |
| **Total** | | **~$2/month** |

## Next Steps

✅ **Monitor for 24 hours** - Observe scaling patterns  
✅ **Review decisions** - Check if actions align with actual load  
✅ **Tune thresholds** - Adjust based on your workload characteristics  
✅ **Set up alerts** - Get notified of scaling actions via SNS  
✅ **Integrate with HPA** - Future: Dynamically adjust HPA min/max  

## Resources

- [Full Documentation](README.md)
- [Extended Architecture](../../docs/architecture-extended.md)
- [AI Autoscaling Instructions](../../docs/ai-autoscaling.instructions.md)
- [Terraform Configuration](../../iac/terraform/lambda-autoscaler.tf)

## Support

For issues or questions:
1. Check CloudWatch logs first
2. Review metrics in dashboard
3. Verify IAM permissions
4. Create issue in GitHub repo
