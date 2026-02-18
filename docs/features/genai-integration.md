---
layout: default
title: GenAI Integration
---

# GenAI Integration (Amazon Bedrock)

Introspect2B integrates Amazon Bedrock into claim workflows through a single API path: `POST /api/claims/{id}/summarize`.

## Workflow

1. Load claim metadata from DynamoDB.
2. Load claim notes from S3.
3. Build a structured prompt.
4. Invoke Bedrock model `amazon.nova-lite-v1:0`.
5. Return four outputs:
   - overall summary
   - customer-facing summary
   - adjuster-focused summary
   - recommended next step

## Why This Pattern

- Keeps business data in AWS-native stores (DynamoDB + S3).
- Makes GenAI inference stateless at API level.
- Keeps model selection configurable for future upgrades.

## Reliability and Cost Notes

- Handle throttling and retries around model invocation.
- Track invocation duration and error rate in CloudWatch.
- Keep prompt templates concise to control latency/token spend.

![Bedrock Dashboard](../media/Dashboard.Cloudwatch.Bedrock.png)
*Bedrock-related metrics used for tuning and autoscaling decisions.*

## Objective Coverage

This chapter directly supports the lab objective to integrate Bedrock for summarization and recommendations.

## Related Docs

- [API Reference](../api-reference)
- [Intelligent Autoscaling](intelligent-autoscaling)
- [Lab Objectives Coverage](../lab-coverage)
