---
layout: default
title: Deployment Troubleshooting
---

# Deployment Troubleshooting

## Fast Triage Sequence

1. Check CodePipeline stage failure and failing CodeBuild project.
2. Check CloudWatch logs for the failing build/deploy step.
3. Validate EKS workload status and events.
4. Validate API Gateway endpoint health.

## Common Issues

### Buildspec tool/runtime mismatch

- Symptom: `tool not found`, engine mismatch, parser errors.
- Fix: align tool install with runtime (`nodejs: 20` for `cdxgen`, .NET SDK for tests).

### Duplicate coverage rows in CodeBuild report

- Symptom: same file appears multiple times with 0/100 values.
- Fix: isolate run output to dedicated results folder and scope report glob.

### Container Insights AccessDenied

- Symptom: `logs:PutLogEvents` denied from node role.
- Fix: patch node role log permissions and restart `cloudwatch-agent` / `fluent-bit`.

### API returns 404 for claim

- Symptom: valid endpoint but claim missing.
- Fix: seed sample data and verify DynamoDB key mapping.

## Verification Commands

```bash
kubectl get pods -n materclaims
kubectl get pods -n amazon-cloudwatch
aws logs describe-log-groups --log-group-name-prefix /aws/containerinsights/materclaims-cluster/
```

## Related Docs

- [Deployment Guide](deployment-guide)
- [Observability](../features/observability)
- [API Reference](../api-reference)
