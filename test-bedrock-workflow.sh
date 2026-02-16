#!/bin/bash

# Test script to verify Bedrock workflow tests locally
# Mimics the tests from .github/workflows/G4.test-and-logs.yml

set -e

NAMESPACE="materclaims"
DEPLOYMENT_NAME="claim-status-api"
LAMBDA_FUNCTION="materclaims-cluster-intelligent-autoscaler"

echo "========================================="
echo "Testing Bedrock Workflow Tests Locally"
echo "========================================="
echo ""

# Test 1: Bedrock Integration Logs
echo "TEST 1: Bedrock Integration Logs"
echo "---------------------------------"
if kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME --tail=100 2>&1 | grep -i "bedrock\|invoke\|nova\|claude" | tail -20; then
    echo "✓ Found Bedrock logs"
else
    echo "✗ No Bedrock logs found (this is normal if no recent API calls)"
fi
echo ""

# Test 2: Bedrock CloudWatch metrics
echo "TEST 2: Bedrock CloudWatch Metrics"
echo "-----------------------------------"
# Calculate timestamps using epoch time (portable)
CURRENT_EPOCH=$(date +%s)
START_EPOCH=$((CURRENT_EPOCH - 600))  # 10 minutes ago

if date --version >/dev/null 2>&1; then
  # GNU date (Linux)
  END_TIME=$(date -u -d "@$CURRENT_EPOCH" +%Y-%m-%dT%H:%M:%S)
  START_TIME=$(date -u -d "@$START_EPOCH" +%Y-%m-%dT%H:%M:%S)
else
  # BSD date (macOS)
  END_TIME=$(date -u -r "$CURRENT_EPOCH" +%Y-%m-%dT%H:%M:%S)
  START_TIME=$(date -u -r "$START_EPOCH" +%Y-%m-%dT%H:%M:%S)
fi

echo "Time range: $START_TIME to $END_TIME"
echo ""

if aws cloudwatch get-metric-statistics \
  --namespace ClaimStatusAPI \
  --metric-name BedrockInferenceDuration \
  --dimensions Name=Service,Value=claim-status-api Name=Model,Value=claude-3-haiku \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 300 \
  --statistics Average,Maximum,SampleCount \
  --output json 2>&1 | grep -q "Datapoints"; then
    echo "✓ Bedrock metrics query succeeded"
    aws cloudwatch get-metric-statistics \
      --namespace ClaimStatusAPI \
      --metric-name BedrockInferenceDuration \
      --dimensions Name=Service,Value=claim-status-api Name=Model,Value=claude-3-haiku \
      --start-time "$START_TIME" \
      --end-time "$END_TIME" \
      --period 300 \
      --statistics Average,Maximum,SampleCount \
      --output json | jq '.Datapoints | length'
else
    echo "⚠️  No Bedrock metrics available (application may not be publishing metrics)"
fi
echo ""

# Test 3: Intelligent autoscaler logs
echo "TEST 3: Intelligent Autoscaler Logs"
echo "------------------------------------"
if aws logs tail /aws/lambda/$LAMBDA_FUNCTION \
    --since 10m \
    --format short \
    --filter-pattern '{ $.decision.action = * }' 2>&1 | head -10; then
    echo "✓ Autoscaler logs retrieved"
else
    echo "✗ No autoscaler activity in last 10 minutes"
fi
echo ""

# Test 4: Bedrock-related scaling decisions
echo "TEST 4: Bedrock-Related Scaling Decisions"
echo "------------------------------------------"
START_MILLIS=$(($(date +%s) - 600))000

if aws logs filter-log-events \
    --log-group-name /aws/lambda/$LAMBDA_FUNCTION \
    --start-time $START_MILLIS \
    --filter-pattern 'Bedrock' \
    --query 'events[*].message' \
    --output text 2>&1 | head -10; then
    echo "✓ Bedrock scaling decisions query succeeded"
else
    echo "✗ No Bedrock-related scaling decisions"
fi
echo ""

# Test 5: List available CloudWatch metrics from the application
echo "TEST 5: List Available CloudWatch Metrics"
echo "------------------------------------------"
echo "Checking what metrics actually exist in ClaimStatusAPI namespace..."
aws cloudwatch list-metrics \
  --namespace ClaimStatusAPI \
  --output table 2>&1 | head -30
echo ""

echo "========================================="
echo "Test Summary"
echo "========================================="
echo "If tests 2-4 show no data, it means the application"
echo "is not publishing CloudWatch metrics for Bedrock."
echo ""
echo "To fix this, the C# application needs to publish"
echo "BedrockInferenceDuration metrics using AWS SDK."
