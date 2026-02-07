#!/bin/bash
# Script to grant CodeBuild service role access to EKS cluster

set -e

CLUSTER_NAME="${1:-materclaims-cluster}"
REGION="${2:-us-east-1}"
STACK_NAME="${3:-introspect2b-codepipeline}"

echo "Fetching CodeBuild role ARN from CloudFormation stack..."
CODEBUILD_ROLE_ARN=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query 'Stacks[0].Outputs[?OutputKey==`CodeBuildServiceRoleArn`].OutputValue' \
  --output text)

if [ -z "$CODEBUILD_ROLE_ARN" ]; then
  echo "ERROR: Could not find CodeBuildServiceRoleArn output in stack $STACK_NAME"
  echo "Attempting to get role ARN from stack resources..."
  CODEBUILD_ROLE_ARN=$(aws cloudformation describe-stack-resources \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --logical-resource-id CodeBuildServiceRole \
    --query 'StackResources[0].PhysicalResourceId' \
    --output text)
  
  if [ -z "$CODEBUILD_ROLE_ARN" ] || [ "$CODEBUILD_ROLE_ARN" = "None" ]; then
    echo "ERROR: Could not determine CodeBuild role ARN"
    exit 1
  fi
  
  # Convert role name to ARN
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  CODEBUILD_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${CODEBUILD_ROLE_ARN}"
fi

echo "CodeBuild Role ARN: $CODEBUILD_ROLE_ARN"

echo "Updating kubeconfig for cluster $CLUSTER_NAME..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo "Adding CodeBuild role to aws-auth ConfigMap..."
kubectl get configmap aws-auth -n kube-system -o yaml > /tmp/aws-auth-backup.yaml
echo "Backup saved to /tmp/aws-auth-backup.yaml"

# Use eksctl to add the role (easier than manual kubectl edit)
if command -v eksctl &> /dev/null; then
  echo "Using eksctl to add IAM role mapping..."
  eksctl create iamidentitymapping \
    --cluster "$CLUSTER_NAME" \
    --region "$REGION" \
    --arn "$CODEBUILD_ROLE_ARN" \
    --username codebuild \
    --group system:masters \
    --no-duplicate-arns
else
  echo "eksctl not found. Please install eksctl or manually add the following to aws-auth ConfigMap:"
  echo ""
  echo "  mapRoles: |"
  echo "    - rolearn: $CODEBUILD_ROLE_ARN"
  echo "      username: codebuild"
  echo "      groups:"
  echo "        - system:masters"
  echo ""
  echo "Run: kubectl edit configmap aws-auth -n kube-system"
fi

echo "Done! CodeBuild should now be able to access the EKS cluster."
