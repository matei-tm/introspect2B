---
layout: default
title: Getting Started
---

# Getting Started with Introspect2B

Deploy the complete GenAI-powered Claim Status API using **GitHub Actions** in 30 minutes. This guide focuses on the automated deployment pipeline - no local tools required!

## Prerequisites

Before you begin, ensure you have:

### GitHub Account
- ✅ Fork this repository to your GitHub account
- ✅ Access to repository Settings (to configure secrets)

### AWS Account
- ✅ AWS Account with administrative access
- ✅ Amazon Bedrock access enabled in your region ([Request access](https://console.aws.amazon.com/bedrock))
- ✅ IAM credentials (Access Key ID and Secret Access Key)
- ✅ Sufficient service quotas for:
  - Amazon EKS (1 cluster)
  - VPC (1 VPC with subnets)
  - EC2 (2 t3.medium instances)
  - DynamoDB (1 table)
  - S3 (1 bucket)

### GitHub Personal Access Token (PAT)
- ✅ Create a [GitHub Personal Access Token](https://github.com/settings/tokens) with:
  - `repo` scope (full control of private repositories)
  - `workflow` scope (update GitHub Actions workflows)
- ✅ Save the token - you'll need it for CodePipeline integration

## Overview: GitHub Actions Workflows

Introspect2B provides 8 automated workflows that handle everything from infrastructure setup to deployment and testing:

| Workflow | Name | Purpose | Required Secrets |
|----------|------|---------|------------------|
| **G1.0** | Lab Setup | Orchestrator that runs cleanup, backend setup, and CodePipeline deployment | All below |
| **G1.1** | API Gateway Cleanup | Removes existing API Gateway stacks (cleanup) | AWS credentials, SITE_USER, SITE_PASSWORD |
| **G1.2** | Setup Terraform Backend | Creates S3 bucket and DynamoDB table for Terraform state | AWS credentials |
| **G1.3** | Deploy CodePipeline | Creates AWS CodePipeline for CI/CD | AWS credentials, CODEPIPELINE_GITHUB_TOKEN |
| **G2** | Terraform Deploy | Deploys infrastructure (EKS, DynamoDB, S3, IAM, Lambda) | AWS credentials |
| **G3** | Auto-trigger CodePipeline | Automatically triggers pipeline on API code changes | AWS credentials |
| **G4** | Test and Collect Logs | Verifies deployment and collects diagnostics | AWS credentials |

## Step 1: Configure GitHub Secrets

## Step 1: Configure GitHub Secrets

Navigate to your forked repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add the following 7 secrets:

### Required Secrets

| Secret Name | Description | How to Get It |
|-------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key ID | From AWS IAM user credentials ([Create IAM user](https://console.aws.amazon.com/iam)) |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret access key | From AWS IAM user credentials (shown once when created) |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID | Run: `aws sts get-caller-identity --query Account --output text` |
| `CODEPIPELINE_GITHUB_TOKEN` | GitHub Personal Access Token | [Create new PAT](https://github.com/settings/tokens) with `repo` and `workflow` scopes |
| `ECR_REGISTRY` | ECR registry URL | `<AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com` |
| `SITE_USER` | Lab environment username (optional) | Your lab username if using managed AWS environment |
| `SITE_PASSWORD` | Lab environment password (optional) | Your lab password if using managed AWS environment |

<details>
<summary><strong>📋 Click to see example values</strong></summary>

```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_ACCOUNT_ID=123456789012
CODEPIPELINE_GITHUB_TOKEN=ghp_1234567890abcdefghijklmnopqrstuvwxyz
ECR_REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com
SITE_USER=your_username
SITE_PASSWORD=your_password
```

**Note:** `SITE_USER` and `SITE_PASSWORD` are only needed if you're using a managed lab environment. For standard AWS accounts, these can be set to dummy values or omitted.

</details>

### Verify Secrets Configuration

After adding all secrets, your Actions secrets page should show 7 secrets.

## Step 2: Deploy Infrastructure (One-Click Setup)

### Option A: Complete Lab Setup (Recommended)

This workflow runs all setup steps in sequence: cleanup, backend setup, and CodePipeline deployment.

![GitHub Workflow Lab Setup](media/Github.Workflow.1.LabSetup.png)
*GitHub Actions workflow for complete lab setup*

1. Navigate to **Actions** tab in your repository
2. Select **"1. Lab Setup"** workflow (G1.0)
3. Click **"Run workflow"** dropdown
4. Configure inputs (or use defaults):
   - **AWS region**: `us-east-1` (default)
   - **API Gateway stack name**: `claim-status-api-apigw` (default)
   - **CodePipeline stack name**: `introspect2b-codepipeline-v2` (default)
   - **Performance pipeline stack**: `introspect2b-codepipeline-perf` (default)
5. Click **"Run workflow"** button
6. ⏱️ Wait 2-3 minutes for completion

**What it does:**
- ✅ Cleans up any existing API Gateway stacks
- ✅ Creates S3 bucket (`introspect2b-terraform-state-<account-id>`) for Terraform state
- ✅ Creates DynamoDB table (`introspect2b-terraform-locks`) for state locking
- ✅ Deploys AWS CodePipeline for application CI/CD
- ✅ Deploys performance testing pipeline

### Option B: Individual Setup Steps

If you prefer granular control, run these workflows individually:

#### 2.1: API Gateway Cleanup (Optional)

Only needed if you have leftover API Gateway stacks from previous deployments:

- **Workflow**: "1.1 API Gateway Cleanup" (G1.1)
- **Duration**: 1 minute
- **Creates**: Nothing (cleanup only)

#### 2.2: Setup Terraform Backend (Required)

#### 2.2: Setup Terraform Backend (Required)

Creates the S3 bucket and DynamoDB table for storing Terraform state:

- **Workflow**: "1.2 Setup Terraform Backend" (G1.2)
- **Duration**: 1-2 minutes
- **Creates**: 
  - S3 bucket: `introspect2b-terraform-state-<account-id>`
  - DynamoDB table: `introspect2b-terraform-locks`

**Steps:**
1. Navigate to **Actions** → **"1.2 Setup Terraform Backend"**
2. Click **"Run workflow"**
3. Confirm AWS region: `us-east-1` (or your preferred region)
4. Click **"Run workflow"** button

#### 2.3: Deploy CodePipeline (Required)

Sets up AWS CodePipeline for automated application builds and deployments:

- **Workflow**: "1.3 Deploy CodePipeline" (G1.3)
- **Duration**: 2-3 minutes
- **Creates**:
  - AWS CodePipeline: `claim-status-api-pipeline`
  - AWS CodeBuild projects for build, test, security scans
  - Performance testing pipeline

**Steps:**
1. Navigate to **Actions** → **"1.3 Deploy CodePipeline"**
2. Click **"Run workflow"**
3. Configure inputs (or use defaults):
   - **AWS region**: `us-east-1`
   - **Stack name**: `introspect2b-codepipeline-v2`
   - **Perf stack**: `introspect2b-codepipeline-perf`
4. Click **"Run workflow"** button

## Step 3: Deploy AWS Infrastructure

Now that the backend is ready, deploy the main infrastructure (EKS cluster, DynamoDB, S3, Lambda):

1. Navigate to **Actions** tab
2. Select **"2. Deploy Terraform Infrastructure"** workflow (G2)
3. Click **"Run workflow"** dropdown
4. Select action: **`apply`**
5. Click **"Run workflow"** button
6. ⏱️ Wait **15-25 minutes** for deployment

### What Gets Created

During this step, Terraform creates all AWS resources:

| Resource | Details | Purpose |
|----------|---------|---------|
| **Amazon EKS** | v1.31 cluster with 2 t3.medium nodes | Kubernetes cluster for microservices |
| **VPC** | Public/private subnets across 2 AZs | Network isolation |
| **DynamoDB** | Table: `claims` (on-demand) | Claim data storage |
| **S3 Bucket** | `claim-notes-<account-id>` | Claim notes storage |
| **ECR Repository** | `claim-status-api` | Container image registry |
| **IAM Roles** | IRSA roles for pods | Secure AWS service access |
| **Lambda Function** | `materclaims-cluster-intelligent-autoscaler` | AI-powered autoscaling |
| **CloudWatch** | Logs, Metrics, Container Insights, Dashboard | Observability |
| **API Gateway** | Regional REST API with AWS_IAM auth | API access layer |

### Monitor Deployment Progress

You can monitor the deployment in real-time:

1. Click on the running workflow in the Actions tab
2. Click on **"Terraform apply"** job
3. Expand steps to see detailed logs:
   - **Terraform Init**: Downloads providers and plugins
   - **Terraform Validate**: Validates configuration syntax
   - **Terraform Plan**: Shows what will be created
   - **Terraform Apply**: Creates all AWS resources

**Expected Duration**: 15-25 minutes

### Terraform Outputs

After successful deployment, Terraform outputs important values:

```hcl
cluster_name = "materclaims-cluster"
cluster_endpoint = "https://XXX.eks.us-east-1.amazonaws.com"
configure_kubectl = "aws eks update-kubeconfig --region us-east-1 --name materclaims-cluster"
dynamodb_table_name = "claims"
claim_notes_bucket_name = "claim-notes-123456789012"
ecr_repositories = {
  claim-status-api = "123456789012.dkr.ecr.us-east-1.amazonaws.com/claim-status-api"
}
intelligent_autoscaler_dashboard_url = "https://console.aws.amazon.com/cloudwatch/..."
```

<details>
<summary><strong>⚠️ Troubleshooting: Terraform Apply Failed</strong></summary>

**Common issues:**

1. **Kubernetes connection errors**: 
   - These have been fixed in the latest version
   - If you still see them, re-run the workflow

2. **Service quota exceeded**:
   - Request quota increase in AWS Service Quotas console
   - Common limits: EKS clusters, VPC, Elastic IPs

3. **State locked**:
   - Wait for other operations to complete
   - Check DynamoDB table for locks

4. **Permission denied**:
   - Verify AWS credentials have Administrator access
   - Check IAM user permissions

**Solution:** Re-run the workflow after addressing the issue. Terraform will resume from where it failed.

</details>

## Step 4: Deploy Application to EKS

The application deployment happens automatically via AWS CodePipeline, but you can also trigger it manually:

### Option A: Auto-Trigger (Recommended)

### Option A: Auto-Trigger (Recommended)

The **"3. Auto-trigger CodePipeline"** workflow (G3) automatically triggers when you push changes to API code:

**Triggered automatically on:**
- Push to `main` branch
- Changes in `src/claim-status-api/**`
- Changes in `pipelines/codebuild/**`
- Changes in `pipelines/codepipeline/**`

**What it does:**
1. Detects code changes
2. Starts AWS CodePipeline execution
3. Provides links to pipeline console

**No manual action required!** Just push your code:

```bash
git add src/claim-status-api/
git commit -m "Update API code"
git push origin main
```

The workflow will automatically:
- ✅ Build .NET application
- ✅ Run unit tests
- ✅ Run security scans (AWS Inspector, Defender)
- ✅ Build Docker image
- ✅ Push to ECR
- ✅ Deploy to EKS
- ✅ Run smoke tests

### Option B: Manual Trigger via AWS Console

You can also manually trigger CodePipeline from AWS Console:

1. Navigate to [AWS CodePipeline Console](https://console.aws.amazon.com/codesuite/codepipeline/pipelines)
2. Select `claim-status-api-pipeline`
3. Click **"Release change"**

![CodePipeline Dashboard](media/CodePipeline.claim-status-api-pipeline.png)
*AWS CodePipeline showing the deployment stages*

### Watch Pipeline Execution

Monitor the pipeline progress:

1. Go to **AWS CodePipeline** console
2. Click on `claim-status-api-pipeline`
3. Watch stages execute:
   - **Source**: Fetches code from GitHub
   - **Build**: Compiles .NET app, runs tests
   - **SecurityScan**: AWS Inspector + Defender scans
   - **DockerBuild**: Builds container image
   - **Deploy**: Updates EKS deployment
   - **Test**: Runs integration tests

**Expected Duration**: 8-12 minutes

## Step 5: Verify Deployment

Use the **"4. Test and Collect Logs"** workflow (G4) to verify everything is working:

1. Navigate to **Actions** → **"4. Test and Collect Logs"**
2. Click **"Run workflow"**
3. Click **"Run workflow"** button
4. Wait 1-2 minutes

### What It Checks

This workflow verifies:
- ✅ EKS cluster connectivity
- ✅ Pod status in `materclaims` namespace
- ✅ CloudWatch Container Insights status
- ✅ Application logs
- ✅ CloudWatch Agent logs
- ✅ Fluent Bit logs

### Review Test Results

After the workflow completes:

1. Click on the completed workflow run
2. Click on **"Test Deployment and Collect Logs"** job
3. Scroll down to **"Summary"** section
4. Review:
   - Pod status (should show `Running`)
   - Service status
   - Recent log entries

**Expected Pod Status:**
```bash
NAME                                READY   STATUS    RESTARTS   AGE
claim-status-api-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
claim-status-api-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
```

## Step 6: Initialize Sample Data

Now that everything is deployed, load sample data into DynamoDB and S3.

### Option A: Using GitHub Actions (Easiest)

Currently, this needs to be done manually (see Option B). A workflow will be added in a future update.

### Option B: Using Local Script

If you have AWS CLI configured locally:

```bash
# Clone the repository (if not already)
git clone https://github.com/<your-username>/introspect2B.git
cd introspect2B

# Run the initialization script
chmod +x scripts/init-sample-data.sh
./scripts/init-sample-data.sh
```

**What it loads:**
- ✅ 8 sample claims in DynamoDB
- ✅ 4 claim note blobs in S3

## Step 7: Test the API

### Via AWS CloudWatch Logs Insights

1. Navigate to [CloudWatch Logs Insights](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:logs-insights)
2. Select log group: `/aws/containerinsights/materclaims-cluster/application`
3. Run a query to see API calls:

![CloudWatch Container Insights Performance Monitor](media/CloudWatch.ContainerInsights.PerfMon.Pods.png)
*CloudWatch Container Insights showing pod-level performance metrics*

```sql
fields @timestamp, @message
| filter @message like /api\/claims/
| sort @timestamp desc
| limit 20
```

### Via kubectl (If you have local AWS CLI)

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name materclaims-cluster

# Port forward to access API locally
kubectl port-forward -n materclaims svc/claim-status-api 8080:80

# In another terminal:
# Test GET endpoint
curl http://localhost:8080/api/claims/CLAIM-001

# Test AI Summary endpoint
curl -X POST http://localhost:8080/api/claims/CLAIM-001/summarize

# Open Swagger UI
open http://localhost:8080/swagger
```

### Via API Gateway (Production Access)

Test the deployed API Gateway endpoint:

1. Get API Gateway URL from [AWS Console](https://console.aws.amazon.com/apigateway)
2. Use AWS SigV4 signing for authentication
3. See [API Reference](api-reference) for details

![API Gateway Resources](media/APIGateway.APIs.Resources-claim-status-api-dev.png)
*Amazon API Gateway showing configured API resources and methods*

## GitHub Actions Workflow Reference

### Complete Deployment Sequence

Here's the recommended order to run workflows for a fresh deployment:

```mermaid
graph TD
    A[1. Fork Repository] --> B[2. Configure GitHub Secrets]
    B --> C[3. Run G1.0: Lab Setup]
    C --> D[4. Run G2: Terraform Deploy]
    D --> E[5. Auto-trigger G3: CodePipeline]
    E --> F[6. Run G4: Test and Collect Logs]
    F --> G[7. Initialize Sample Data]
    G --> H[8. Test API]
    
    style C fill:#90EE90
    style D fill:#87CEEB
    style E fill:#FFB6C1
    style F fill:#DDA0DD
```

### Workflow Details

#### G1.0: Lab Setup (Orchestrator)
- **Purpose**: One-click setup of all prerequisites
- **Runs**: G1.1 → G1.2 → G1.3
- **Duration**: 2-3 minutes
- **Use When**: Starting fresh or resetting environment

#### G1.1: API Gateway Cleanup
- **Purpose**: Remove old API Gateway stacks
- **Duration**: 1 minute
- **Use When**: Cleanup before redeployment

#### G1.2: Setup Terraform Backend
- **Purpose**: Create S3 and DynamoDB for Terraform state
- **Duration**: 1-2 minutes  
- **Use When**: First-time setup or backend recreation

#### G1.3: Deploy CodePipeline
- **Purpose**: Deploy AWS CodePipeline for CI/CD
- **Duration**: 2-3 minutes
- **Use When**: Setting up automated deployments

#### G2: Terraform Deploy
- **Purpose**: Deploy full AWS infrastructure (EKS, DynamoDB, S3, etc.)
- **Duration**: 15-25 minutes
- **Actions**: `plan`, `apply`, `destroy`
- **Use When**: Infrastructure deployment or updates

#### G3: Auto-trigger CodePipeline
- **Purpose**: Automatically trigger pipeline on code changes
- **Duration**: Instant trigger, pipeline runs 8-12 minutes
- **Trigger**: Automatic on push to `main` with API changes
- **Use When**: Deploying application updates

#### G4: Test and Collect Logs
- **Purpose**: Verify deployment and gather diagnostics
- **Duration**: 1-2 minutes
- **Use When**: After deployment, troubleshooting

#### G5: Publish Wiki
- **Purpose**: Generate PDF documentation from wiki
- **Duration**: 3-5 minutes
- **Use When**: Creating documentation deliverables

## Observability and Monitoring

### CloudWatch Dashboard

After deployment, access the intelligent autoscaler dashboard:

![CloudWatch Bedrock Dashboard](media/Dashboard.Cloudwatch.Bedrock.png)
*CloudWatch dashboard showing Bedrock inference metrics and API performance*

1. Get the URL from Terraform outputs:
   ```
   intelligent_autoscaler_dashboard_url = "https://console.aws.amazon.com/cloudwatch/..."
   ```

2. Or navigate manually:
   - Go to [CloudWatch Dashboards](https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards)
   - Select: `materclaims-cluster-intelligent-autoscaler`

**Dashboard includes:**
- 📊 Pod CPU and Memory utilization
- 📈 Scaling decisions over time
- ⚡ Bedrock invocation metrics
- ⏱️ API request latency

### CloudWatch Log Groups

Monitor application activity:

| Log Group | Purpose |
|-----------|---------|
| `/aws/containerinsights/materclaims-cluster/application` | Application logs |
| `/aws/lambda/intelligent-autoscaler` | Autoscaler decisions |
| `/aws/eks/materclaims-cluster/cluster` | EKS cluster logs |
| `/aws/codebuild/*` | CI/CD build logs |

### Pre-built Log Queries

Use the 8 pre-built CloudWatch Insights queries in [observability/log-insights/queries.json](../observability/log-insights/queries.json):

1. API request tracing
2. Error analysis
3. Bedrock invocation metrics
4. Autoscaling decisions
5. Performance analysis
6. Security audit trail
7. Resource utilization
8. Health check monitoring

## Troubleshooting

## Troubleshooting

### GitHub Actions Workflow Failures

<details>
<summary><strong>❌ G1.2: Terraform Backend Setup Failed</strong></summary>

**Symptoms:**
- Error: "AccessDenied: User is not authorized to perform: s3:CreateBucket"

**Solutions:**
1. Verify AWS credentials have administrative permissions
2. Check IAM user has `AmazonS3FullAccess` and `AmazonDynamoDBFullAccess`
3. Confirm `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` secrets are correct
4. Try deleting and recreating the secrets

</details>

<details>
<summary><strong>❌ G2: Terraform Apply - Connection Refused</strong></summary>

**Symptoms:**
- Error: "dial tcp [::1]:80: connect: connection refused"
- Related to Kubernetes service account data sources

**Solutions:**
- **Fixed in latest version!** Pull the latest changes:
  ```bash
  git pull upstream main
  git push origin main
  ```
- Re-run the workflow

</details>

<details>
<summary><strong>❌ G2: Terraform Apply - EKS Cluster Creation Failed</strong></summary>

**Symptoms:**
- Error: "Error creating EKS Cluster: LimitExceededException"

**Solutions:**
1. Check AWS service quotas:
   - Go to [Service Quotas Console](https://console.aws.amazon.com/servicequotas)
   - Increase limits for: EKS clusters, VPC, Elastic IPs
2. Delete any unused EKS clusters in the region
3. Try a different AWS region

</details>

<details>
<summary><strong>❌ G3: CodePipeline Trigger Failed</strong></summary>

**Symptoms:**
- Error: "Pipeline not found"

**Solutions:**
1. Ensure G1.3 (Deploy CodePipeline) completed successfully
2. Verify CloudFormation stack `introspect2b-codepipeline-v2` exists
3. Check AWS CodePipeline console for pipeline status
4. Re-run G1.3 workflow

</details>

<details>
<summary><strong>❌ G4: Test Workflow - Cluster Access Denied</strong></summary>

**Symptoms:**
- Error: "error: You must be logged in to the server (Unauthorized)"

**Solutions:**
1. Verify EKS cluster is running
2. Check IAM credentials are valid
3. Ensure the cluster name is correct: `materclaims-cluster`
4. Wait 2-3 minutes after Terraform apply before running tests

</details>

### AWS Infrastructure Issues

<details>
<summary><strong>Pods not starting (ImagePullBackOff)?</strong></summary>

**Symptoms:**
```bash
NAME                                READY   STATUS             RESTARTS   AGE
claim-status-api-xxxxxxxxxx-xxxxx   0/1     ImagePullBackOff   0          2m
```

**Solutions:**
1. **Check if CodePipeline completed successfully**:
   - Go to AWS CodePipeline console
   - Verify pipeline execution succeeded
   
2. **Verify ECR image exists**:
   ```bash
   aws ecr describe-images \
     --repository-name claim-status-api \
     --region us-east-1
   ```

3. **Check pod events**:
   ```bash
   kubectl describe pod <pod-name> -n materclaims
   ```

4. **Manually trigger pipeline**: Run G3 workflow or use AWS Console

</details>

<details>
<summary><strong>API returning 404 for valid claim IDs?</strong></summary>

**Symptoms:**
- API responds but returns 404 for `CLAIM-001`

**Solutions:**
1. **Verify sample data was loaded**:
   ```bash
   aws dynamodb get-item \
     --table-name claims \
     --key '{"id":{"S":"CLAIM-001"}}' \
     --region us-east-1
   ```

2. **Check S3 bucket exists and has data**:
   ```bash
   aws s3 ls s3://claim-notes-$(aws sts get-caller-identity --query Account --output text)/ --recursive
   ```

3. **Re-run sample data script**:
   ```bash
   ./scripts/init-sample-data.sh
   ```

</details>

<details>
<summary><strong>Bedrock access denied (403)?</strong></summary>

**Symptoms:**
- POST `/api/claims/{id}/summarize` returns 403
- Logs show: "AccessDeniedException: User is not authorized to perform: bedrock:InvokeModel"

**Solutions:**
1. **Verify Bedrock is enabled in your region**:
   ```bash
   aws bedrock list-foundation-models --region us-east-1
   ```

2. **Request access to Claude 3 Haiku**:
   - Go to [Bedrock Console](https://console.aws.amazon.com/bedrock)
   - Navigate to "Model access"
   - Request access to "Anthropic Claude 3 Haiku"

3. **Check IAM role permissions**:
   ```bash
   kubectl describe sa claim-status-api-sa -n materclaims
   ```

4. **Wait 5-10 minutes** after requesting Bedrock access for permissions to propagate

</details>

<details>
<summary><strong>Terraform state locked?</strong></summary>

**Symptoms:**
- Error: "Error locking state: Error acquiring the state lock"

**Solutions:**
1. **Wait for other operations to complete** (if running multiple workflows)

2. **Check DynamoDB locks table**:
   - Go to [DynamoDB Console](https://console.aws.amazon.com/dynamodb)
   - Table: `introspect2b-terraform-locks`
   - Check for active locks

3. **Force unlock** (use with extreme caution):
   ```bash
   # Get lock ID from error message
   cd iac/terraform
   terraform force-unlock <lock-id>
   ```

</details>

### GitHub Secrets Issues

<details>
<summary><strong>Workflow fails with "secret not found"?</strong></summary>

**Solutions:**
1. Verify all 7 secrets are configured:
   - Go to Settings → Secrets and variables → Actions
   - Confirm: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ACCOUNT_ID`, `CODEPIPELINE_GITHUB_TOKEN`, `ECR_REGISTRY`, `SITE_USER`, `SITE_PASSWORD`

2. **Check secret names match exactly** (case-sensitive)

3. **Re-create secrets** if values might be incorrect

4. **Use dummy values for optional secrets**:
   - `SITE_USER`: `dummy_user` (if not using managed lab)
   - `SITE_PASSWORD`: `dummy_pass` (if not using managed lab)

</details>

### Get Help

- 📝 View detailed logs in GitHub Actions workflow runs
- 🔍 Check CloudWatch Logs for application errors
- 🐛 [Report an Issue](https://github.com/matei-tm/introspect2B/issues)
- 💬 [GitHub Discussions](https://github.com/matei-tm/introspect2B/discussions)
- 📖 [Full Documentation](https://matei-tm.github.io/introspect2B/)

## Cleanup

When you're done experimenting, clean up all AWS resources to avoid charges:

### Option A: Using GitHub Actions (Recommended)

1. Navigate to **Actions** → **"2. Deploy Terraform Infrastructure"**
2. Click **"Run workflow"**
3. Select action: **`destroy`**
4. Click **"Run workflow"** button
5. ⏱️ Wait 10-15 minutes for complete teardown

### Option B: Manual Cleanup

If you have Terraform installed locally:

```bash
cd iac/terraform
terraform destroy -auto-approve
```

### Complete Cleanup Checklist

After running destroy, verify these resources are deleted:

- ✅ EKS cluster deleted
- ✅ EC2 instances terminated
- ✅ VPC and subnets removed
- ✅ DynamoDB table deleted
- ✅ S3 bucket emptied and deleted
- ✅ CloudWatch log groups deleted
- ✅ ECR repository deleted
- ✅ Lambda function deleted
- ✅ IAM roles and policies removed
- ✅ API Gateway deleted (via G1.1 workflow)
- ✅ CodePipeline stack deleted (CloudFormation console)

<div class="warning-box">
  <strong>⚠️ Important</strong>
  <p>Terraform destroy will delete ALL resources including data in DynamoDB and S3. Ensure you've backed up any important data before destroying.</p>
</div>

## Next Steps

### Explore Features

- 📖 [API Reference](api-reference) - Complete endpoint documentation with examples
- 🤖 [Intelligent Autoscaling](features/intelligent-autoscaling) - How AI-powered scaling works

### Understand Architecture

- 🏗️ [System Architecture](architecture/overview) - High-level design and components
- 📊 [Extended Architecture](architecture/extended) - Deep dive into autoscaling

### Advanced Topics

- 🚀 [Advanced Deployment](deployment/deployment-guide) - Production-ready patterns

---

**🎉 Congratulations!** You've successfully deployed a production-ready, GenAI-powered microservices application on AWS using GitHub Actions. The system includes intelligent autoscaling, comprehensive observability, and enterprise-grade security.
