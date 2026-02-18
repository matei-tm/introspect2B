---
layout: default
title: Lab Objectives Coverage
---

# Lab Objectives Coverage

This page maps implemented documentation and artifacts to `lab-objectives.instructions.md`.

## Objective Mapping

| Lab Objective | Coverage Evidence |
|---|---|
| EKS on EC2 platform | [System Architecture](architecture/overview), [Deployment Guide](deployment/deployment-guide), `iac/terraform/eks.tf` |
| Expose API via API Gateway | [API Reference](api-reference), `apigw/` templates and policy files |
| Bedrock summarization integration | [GenAI Integration](features/genai-integration), [API Reference](api-reference) |
| CI/CD for Kubernetes workloads | `pipelines/codepipeline/pipeline.yaml`, `pipelines/codebuild/*`, [Deployment Guide](deployment/deployment-guide) |
| Security scanning + visibility | [Security Architecture](architecture/security), `scans/`, SecurityScan CodeBuild job |
| Observability for API + workloads | [Observability](features/observability), `observability/`, CloudWatch dashboards |
| Use GenAI as engineering assistant | Prompt-driven Bedrock flow + autoscaling guidance in docs and workflows |

## Functional Requirements Check

- `GET /claims/{id}` documented and implemented.
- `POST /claims/{id}/summarize` documented and implemented.
- Summarization outputs include overall/customer/adjuster/recommended-next-step.

## Deliverables Check

The required folders and evidence paths are present:

- `src/`, `mocks/`, `apigw/`, `iac/`, `pipelines/`, `scans/`, `observability/`, root `README.md`.

## Gaps to Watch

- Keep screenshots in `scans/` and `observability/` current after each pipeline run.
- Keep query library updated when logging format changes.
