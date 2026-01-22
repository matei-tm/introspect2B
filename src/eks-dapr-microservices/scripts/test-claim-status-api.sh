#!/bin/bash

NAMESPACE="dapr-demo"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "🧪 Testing Claim Status API"
echo "============================"
echo ""

# Get the service endpoint
SERVICE_IP=$(kubectl get svc -n $NAMESPACE claim-status-api -o jsonpath='{.spec.clusterIP}')
PORT=$(kubectl get svc -n $NAMESPACE claim-status-api -o jsonpath='{.spec.ports[0].port}')

echo "Service: http://${SERVICE_IP}:${PORT}"
echo ""

# Test 1: Get claim status
echo "📋 Test 1: GET /api/claims/{id}"
echo "URL: GET http://${SERVICE_IP}:${PORT}/api/claims/CLAIM-001"
echo ""

# Test 2: Summarize claim
echo "🤖 Test 2: POST /api/claims/{id}/summarize"
echo "URL: POST http://${SERVICE_IP}:${PORT}/api/claims/CLAIM-001/summarize"
echo "Body:"
echo '{
  "notesOverride": "Customer reported water damage to kitchen and dining room after pipe burst. Occurred on January 15, 2024. Damage includes flooring, cabinetry, and personal items. Estimated repair cost: $25,000. No previous claims. Homeowners insurance active for 5 years."
}'
echo ""

echo "✅ API is ready for testing!"
echo ""
echo "Run tests with kubectl port-forward:"
echo "  kubectl port-forward -n $NAMESPACE svc/claim-status-api 8080:80"
echo ""
echo "Then use curl or Postman to test the endpoints."
