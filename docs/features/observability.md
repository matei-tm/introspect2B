---
layout: default
title: Observability
---

# Observability

Observability is implemented with CloudWatch metrics, logs, dashboards, and Container Insights.

## Log Groups Used

- `/aws/containerinsights/materclaims-cluster/application`
- `/aws/containerinsights/materclaims-cluster/dataplane`
- `/aws/containerinsights/materclaims-cluster/host`
- `/aws/containerinsights/materclaims-cluster/performance`

## What Is Monitored

- API latency, volume, and error patterns
- Bedrock invocation duration and behavior
- pod restarts and runtime issues
- IAM/authorization error patterns
- autoscaler decisions and trigger context

## Logs Insights Queries

Saved queries are maintained in:

- [queries.json (repository)](https://github.com/matei-tm/introspect2B/blob/main/observability/log-insights/queries.json)

Each query now has an explicit `logGroup` for repeatable execution.

## Dashboards and Evidence

![Container Insights](../media/CloudWatch.ContainerInsights.1.png)
*Container-level health and utilization in EKS.*

![Logs Insights](../media/CloudWatch.LogsInsights.Query1.png)
*Logs Insights query outputs used for diagnostics.*

## Quick Verification

- Confirm CloudWatch Observability add-on is `ACTIVE`.
- Confirm `cloudwatch-agent` and `fluent-bit` pods are healthy.
- Confirm recent metrics and logs are arriving for all required groups.

## Related Docs

- [System Architecture](../architecture/overview)
- [Lab Objectives Coverage](../lab-coverage)
- [Evaluation Readiness](../evaluation-readiness)
