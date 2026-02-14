---
layout: default
title: Getting Started
---

# Getting Started with Introspect2B

Get the Claim Status API up and running in **30 minutes**.

## Prerequisites

Before you begin, ensure you have:

### Required Tools
- ✅ **AWS CLI** (v2.x) configured with credentials
- ✅ **kubectl** (v1.28+) for Kubernetes management
- ✅ **Terraform** (v1.6+) for infrastructure provisioning
- ✅ **Git** for repository cloning

### AWS Requirements
- ✅ AWS Account with administrative access
- ✅ Amazon Bedrock access enabled in your region ([Request access](https://console.aws.amazon.com/bedrock))
- ✅ AWS CLI configured (`aws configure`)
- ✅ Sufficient service quotas for EKS, EC2, VPC

### Optional (for development)
- 🔧 Docker Desktop (for local testing)
- 🔧 .NET 8 SDK (for local development)
- 🔧 Visual Studio Code or similar IDE

## Quick Deploy (30 minutes)

### Step 1: Clone the Repository

```bash
git clone https://github.com/matei-tm/introspect2B.git
cd introspect2B
```

### Step 2: Deploy Using GitHub Actions (Recommended)

<div class="info-box">
  <strong>🎯 Automated Deployment</strong>
  <p>The fastest way to deploy is using the included GitHub Actions workflows.</p>
</div>

1. **Fork the repository** to your GitHub account

2. **Configure AWS Secrets** in GitHub:
   - Go to Settings → Secrets and variables → Actions
   - Add the following secrets:
     - `AWS_ACCESS_KEY_ID`
     - `AWS_SECRET_ACCESS_KEY`
     - `AWS_SESSION_TOKEN` (if using temporary credentials)

3. **Run the Deployment Workflow**:
   - Navigate to Actions → "2. Deploy Terraform Infrastructure"
   - Click "Run workflow"
   - Select `action: apply`
   - Wait ~20 minutes for infrastructure creation

4. **Deploy the Application**:
   - Navigate to Actions → "Deploy to AWS"
   - Click "Run workflow"
   - Wait ~5 minutes for application deployment

5. **Initialize Sample Data**:
   ```bash
   ./scripts/init-sample-data.sh
   ```

### Step 3: Manual Deployment (Local Terraform)

If you prefer local deployment:

#### 3a. Setup Terraform Backend (One-time)

```bash
# Run the backend setup script
cd iac/terraform
./backend-setup.sh

# Or use GitHub Actions workflow:
# Actions → "1.2 Setup Terraform Backend" → Run workflow
```

#### 3b. Deploy Infrastructure

```bash
cd iac/terraform

# Initialize Terraform
terraform init

# Review the infrastructure plan
terraform plan

# Apply infrastructure (creates EKS, DynamoDB, S3, IAM)
terraform apply -auto-approve
```

**What gets created:**
- ✅ Amazon EKS cluster (1.31) with 2 t3.medium nodes
- ✅ VPC with public/private subnets across 2 AZs
- ✅ DynamoDB table for claim data
- ✅ S3 bucket for claim notes
- ✅ IAM roles with IRSA for Kubernetes
- ✅ ECR repository for container images
- ✅ CloudWatch Logs and Container Insights
- ✅ Intelligent Autoscaler Lambda function

**Expected time:** 15-20 minutes

#### 3c. Configure kubectl Access

```bash
# Update kubeconfig for EKS access
aws eks update-kubeconfig \
  --region us-east-1 \
  --name materclaims-cluster

# Verify connection
kubectl get nodes
```

#### 3d. Build and Deploy Application

```bash
# Set environment variables
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Build and push Docker image (automated via CodePipeline)
# Or manually:
cd src/claim-status-api
docker build --platform linux/amd64 -t claim-status-api:latest .
docker tag claim-status-api:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/claim-status-api:latest

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Push image
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/claim-status-api:latest

# Deploy to Kubernetes
kubectl apply -f k8s/
```

#### 3e. Initialize Sample Data

```bash
# Load 8 sample claims and 4 note blobs
./scripts/init-sample-data.sh
```

**Expected time:** 5-10 minutes

## Verify Deployment

### Check Kubernetes Resources

```bash
# View running pods
kubectl get pods -n materclaims

# Expected output:
# NAME                                READY   STATUS    RESTARTS   AGE
# claim-status-api-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# claim-status-api-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# View service
kubectl get svc -n materclaims claim-status-api

# View deployments
kubectl get deployment -n materclaims
```

### Test the API

```bash
# Port forward to access the API locally
kubectl port-forward -n materclaims svc/claim-status-api 8080:80 &

# Test GET endpoint
curl http://localhost:8080/api/claims/CLAIM-001

# Test AI Summary endpoint
curl -X POST http://localhost:8080/api/claims/CLAIM-001/summarize \
  -H "Content-Type: application/json"

# Access Swagger UI
open http://localhost:8080/swagger
```

### View Logs

```bash
# Stream logs from all pods
kubectl logs -n materclaims -l app=claim-status-api -f

# View CloudWatch Logs
aws logs tail /aws/containerinsights/materclaims-cluster/application --follow
```

## Next Steps

### Explore the API

- 📖 [API Reference](../api-reference) - Full endpoint documentation
- 🧪 [Testing Guide](../development/testing) - Run unit and integration tests
- 📊 [Observability](../features/observability) - CloudWatch dashboards and queries

### Understand the Architecture

- 🏗️ [System Architecture](../architecture/overview) - High-level design
- 🤖 [Intelligent Autoscaling](../features/intelligent-autoscaling) - AI-powered scaling
- 🔐 [Security Model](../architecture/security) - IAM and network security

### Customize the Deployment

- ⚙️ [Configuration Guide](../deployment/configuration) - Terraform variables
- 🔧 [Advanced Deployment](../deployment/deployment-guide) - Production deployment patterns
- 🚀 [CI/CD Integration](../deployment/github-actions) - Automated pipelines

## Troubleshooting

### Common Issues

<details>
<summary><strong>Pods not starting?</strong></summary>

```bash
# Check pod events
kubectl describe pod <pod-name> -n materclaims

# Check service account permissions
kubectl get sa -n materclaims
kubectl describe sa claim-status-api-sa -n materclaims
```
</details>

<details>
<summary><strong>API returning 404?</strong></summary>

```bash
# Verify claim data exists
aws dynamodb get-item \
  --table-name claims \
  --key '{"id":{"S":"CLAIM-001"}}' \
  --region us-east-1

# Check S3 bucket
aws s3 ls s3://claim-notes-${AWS_ACCOUNT_ID}/ --recursive
```
</details>

<details>
<summary><strong>Bedrock access denied?</strong></summary>

1. Verify Bedrock is enabled in your region:
   ```bash
   aws bedrock list-foundation-models --region us-east-1
   ```

2. Check IAM role permissions:
   ```bash
   kubectl describe sa claim-status-api-sa -n materclaims
   aws iam get-role --role-name <role-name>
   ```

3. Ensure Claude 3 Haiku model is available:
   ```bash
   aws bedrock list-foundation-models --region us-east-1 \
     --query 'modelSummaries[?contains(modelId, `claude-3-haiku`)]'
   ```
</details>

<details>
<summary><strong>Terraform state locked?</strong></summary>

```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>

# Or delete and recreate S3 backend
cd iac/terraform
./backend-setup.sh --force-recreate
```
</details>

### Get Help

- 📝 [Full Troubleshooting Guide](../deployment/troubleshooting)
- 🐛 [Report an Issue](https://github.com/matei-tm/introspect2B/issues)
- 💬 [GitHub Discussions](https://github.com/matei-tm/introspect2B/discussions)

## Cleanup

When you're done experimenting:

```bash
# Delete Kubernetes resources
kubectl delete namespace materclaims

# Destroy AWS infrastructure
cd iac/terraform
terraform destroy -auto-approve

# Or use GitHub Actions:
# Actions → "2. Deploy Terraform Infrastructure" → Run workflow → action: destroy
```

<div class="warning-box">
  <strong>⚠️ Warning</strong>
  <p>This will delete all resources including data in DynamoDB and S3. Make sure to backup any important data first.</p>
</div>

---

**Ready for more?** Continue with the [API Reference](../api-reference) to explore all available endpoints or dive into [Architecture Overview](../architecture/overview) to understand the system design.
