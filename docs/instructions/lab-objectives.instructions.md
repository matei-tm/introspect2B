# INTROSPECT 2B

## 1. Overview

In this lab, participants independently design and implement a GenAI-enabled Claim Status API on AWS using Amazon EKS (on EC2) and Amazon API Gateway. The lab mirrors real enterprise constraints by limiting service choices and avoiding fully managed abstractions such as Fargate.

Participants are expected to apply their existing AWS and Kubernetes knowledge to provision infrastructure, deploy workloads, integrate GenAI using Amazon Bedrock, and establish CI/CD, security, and observability controls.

This is a design-and-build lab, not a guided exercise. Architectural decisions, implementation approaches, and trade-offs are intentionally left to the participant.

## 2. Objectives

- Design and provision a Kubernetes platform on AWS using Amazon EKS with EC2 worker nodes
- Deploy and expose a containerized API through Amazon API Gateway
- Integrate Amazon Bedrock into an application workflow for text summarization and recommendations
- Implement CI/CD pipelines for Kubernetes workloads using AWS-native tools
- Apply container image security scanning and centralized security visibility
- Enable observability for APIs and Kubernetes workloads
- Use GenAI as an engineering assistant across development, security, operations, and documentation

## 3. Key AWS Services Used

- **Amazon EKS** – Kubernetes control plane for application deployment
- **Amazon EC2** – Worker nodes for the EKS cluster (approved instance types only)
- **Amazon ECR** – Container image repository
- **Amazon API Gateway** – External REST API entry point
- **Amazon DynamoDB** – Claim status data store
- **Amazon S3** – Storage for claim notes used in summarization
- **Amazon Bedrock** – Foundation models for GenAI summarization
- **AWS CodePipeline** – CI/CD orchestration
- **AWS CodeBuild** – Build, image publishing, and deployment automation
- **Amazon Inspector** – Container image vulnerability scanning
- **AWS Security Hub** – Centralized security findings
- **Amazon CloudWatch** – Logs, metrics, and operational visibility

## 4. Lab Scope and Expectations

- Create all required infrastructure as part of the lab
- Make their own architectural and implementation decisions
- Validate functionality, security, and observability independently
- Document assumptions and trade-offs where relevant

**Note:** The lab does not provide step-by-step instructions, prebuilt templates, or prescriptive patterns.

## 5. Functional Requirements

### GET /claims/{id}

Returns claim status information from DynamoDB

### POST /claims/{id}/summarize

Reads claim notes from S3

Invokes Amazon Bedrock to generate:
- Overall summary
- Customer-facing summary
- Adjuster-focused summary
- Recommended next step

## 6. Deliverables (to be pushed to GitHub repo)

Repository should contain:

- **src/** — Service source + Dockerfile
- **mocks/claims.json, mocks/notes.json** — 5–8 claim records; 3–4 notes blobs
- **apigw/** — API Gateway policy files or export
- **iac/** — CloudFormation/Terraform templates
- **pipelines/** — AWS pipeline (CodeBuild and CodePipeline)
- **scans/** — Link/screenshots to Inspector findings
- **observability/** — Saved Logs Insight queries and sample screenshots
- **README.md** — Instructions, GenAI prompts used, how to run/tests

## 7. Lab Completeness and Evaluation Criteria

The lab is evaluated based on outcomes, design quality, and operational readiness.

**Completion evidence includes:**

- Running EKS cluster and healthy workloads
- Functional API endpoints via API Gateway
- Clear GenAI integration using Amazon Bedrock
- CI/CD automation with container scanning
- Observable logs and metrics
- Documented architectural reasoning