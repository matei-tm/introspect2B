# Quick Start: Claim Status API

Get the Claim Status API up and running in 5 minutes.

## Prerequisites

- AWS CLI configured
- kubectl configured for EKS
- Docker installed
- Terraform installed

## Quick Deploy

### 1️⃣ Deploy Infrastructure (3 min)

```bash
cd iac/terraform

terraform init
terraform apply -auto-approve
```

**Creates:**

- EKS cluster
- DynamoDB table
- S3 bucket
- IAM roles

### 2️⃣ Deploy Service (2 min)

```bash
cd src/eks-dapr-microservices

./scripts/deploy-claim-status-api.sh
```

**Builds, pushes, and deploys:**

- Docker image to ECR
- Kubernetes deployment (2 replicas)
- Service endpoint

### 3️⃣ Initialize Data (30 sec)

```bash
./scripts/init-sample-data.sh
```

**Creates sample data:**

- Claim in DynamoDB
- Notes in S3

## Test the API

### Port Forward

```bash
kubectl port-forward -n materclaims svc/claim-status-api 8080:80 &
```

### Test Endpoints

**Get Claim Status:**

```bash
curl http://localhost:8080/api/claims/CLAIM-001
```

**Generate AI Summary:**

```bash
curl -X POST http://localhost:8080/api/claims/CLAIM-001/summarize \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Swagger UI:**

```bash
open http://localhost:8080/swagger
```

## View Logs

```bash
kubectl logs -n materclaims -l app=claim-status-api -f
```

## Scale the Service

```bash
kubectl scale deployment -n materclaims claim-status-api --replicas=3
```

## Check Status

```bash
# Deployment status
kubectl get deployment -n materclaims claim-status-api

# Pod status
kubectl get pods -n materclaims -l app=claim-status-api

# Service endpoint
kubectl get svc -n materclaims claim-status-api
```

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete deployment -n materclaims claim-status-api
kubectl delete svc -n materclaims claim-status-api

# Destroy AWS infrastructure
cd iac/terraform
terraform destroy -auto-approve
```

## API Examples

### Get Claim

```bash
curl http://localhost:8080/api/claims/CLAIM-001
```

Response:

```json
{
  "id": "CLAIM-001",
  "status": "Under Review",
  "claimType": "Property",
  "submissionDate": "2024-01-15T10:30:00Z",
  "claimantName": "John Doe",
  "amount": 25000.00,
  "notesKey": "claims/CLAIM-001/notes.txt"
}
```

### Summarize Claim

```bash
curl -X POST http://localhost:8080/api/claims/CLAIM-001/summarize
```

Response:

```json
{
  "claimId": "CLAIM-001",
  "overallSummary": "Property damage claim for $25,000 currently under review.",
  "customerFacingSummary": "Your claim has been received and is being carefully reviewed by our team.",
  "adjusterFocusedSummary": "Detailed assessment of water damage...",
  "recommendedNextStep": "Schedule property inspection for damage verification.",
  "generatedAt": "2024-01-23T14:30:00Z",
  "model": "anthropic.claude-3-haiku-20240307-v1:0"
}
```

## Troubleshooting

### Pods not starting?

```bash
kubectl describe pod <pod-name> -n materclaims
```

### API returning 404?

```bash
# Check claim exists
aws dynamodb get-item \
  --table-name claims \
  --key '{"id":{"S":"CLAIM-001"}}' \
  --region us-east-1
```

### S3 errors?

```bash
# Check bucket exists
aws s3 ls | grep claim-notes
```

## Architecture

```
Claim Status API (2 replicas)
    ↓
    ├→ DynamoDB (Claim data)
    ├→ S3 (Claim notes)
    └→ Bedrock (AI summaries)
```

## Documentation

- 📚 [Full Deployment Guide](./DEPLOYMENT_GUIDE.md)
- 📖 [Implementation Summary](./IMPLEMENTATION_SUMMARY.md)
- 🔧 [Service README](./src/eks-dapr-microservices/claim-status-api/README.md)

## Support

For detailed information, see:

- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Full deployment instructions
- [IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md) - Architecture details
- Service logs: `kubectl logs -n materclaims -l app=claim-status-api -f`

---

**Estimated Time:** 5 minutes ⏱️

**Key Commands:**

```bash
# Deploy
./scripts/deploy-claim-status-api.sh

# Test
kubectl port-forward -n materclaims svc/claim-status-api 8080:80
curl http://localhost:8080/api/claims/CLAIM-001

# Monitor
kubectl logs -n materclaims -l app=claim-status-api -f
```

**Happy deploying! 🚀**
