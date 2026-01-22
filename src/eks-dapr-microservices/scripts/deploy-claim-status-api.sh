#!/bin/bash
set -e

NAMESPACE="dapr-demo"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "🏗️  Building and deploying Claim Status API"
echo "==========================================="
echo "AWS Region: $AWS_REGION"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "ECR Repo: $ECR_REPO_URL"
echo ""

# Change to the claim-status-api directory
cd "$(dirname "$0")"/../claim-status-api

# Build Docker image
echo "🐳 Building Docker image..."
docker build -t claim-status-api:latest .
docker tag claim-status-api:latest ${ECR_REPO_URL}/claim-status-api:latest

# Login to ECR
echo "🔐 Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

# Push to ECR
echo "📤 Pushing image to ECR..."
docker push ${ECR_REPO_URL}/claim-status-api:latest

# Create namespace if it doesn't exist
echo "📦 Creating Kubernetes namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Apply Kubernetes manifests
echo "🚀 Deploying to Kubernetes..."
kubectl apply -f ../k8s/claim-status-api-deployment.yaml
kubectl apply -f ../k8s/claim-status-api-service.yaml

# Wait for deployment
echo "⏳ Waiting for deployment to be ready..."
kubectl rollout status deployment/claim-status-api -n $NAMESPACE

echo ""
echo "✅ Claim Status API deployed successfully!"
echo ""
echo "Access the service:"
echo "  kubectl port-forward -n $NAMESPACE svc/claim-status-api 8080:80"
echo "  curl http://localhost:8080/swagger"
echo ""
echo "Get pod status:"
echo "  kubectl get pods -n $NAMESPACE -l app=claim-status-api"
echo ""
echo "View logs:"
echo "  kubectl logs -n $NAMESPACE -l app=claim-status-api -f"
