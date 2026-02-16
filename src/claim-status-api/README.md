# Claim Status API

A GenAI-enabled Claim Status API built with .NET 10 that integrates with AWS services:

- **DynamoDB** for claim status storage
- **S3** for claim notes
- **Amazon Bedrock** (Claude 3 Haiku) for AI-powered summaries

## Features

### Endpoints

#### GET /api/claims/{id}

Retrieves claim status information from DynamoDB.

**Response (200 OK):**

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

#### POST /api/claims/{id}/summarize

Generates AI-powered summaries for a claim using Amazon Bedrock (Nova).

**Request Body (optional):**

```json
{
  "notesOverride": "Custom claim notes text (optional)"
}
```

**Response (200 OK):**

```json
{
  "claimId": "CLAIM-001",
  "overallSummary": "Property damage claim for $25,000 currently under review.",
  "customerFacingSummary": "Your claim has been received and is being carefully reviewed by our team.",
  "adjusterFocusedSummary": "Detailed assessment of damage with recommendations for claim approval.",
  "recommendedNextStep": "Schedule property inspection for damage verification.",
  "generatedAt": "2024-01-23T14:30:00Z",
  "model": "anthropic.claude-3-haiku-20240307-v1:0"
}
```

## Architecture

### Services

- **DynamoDbService**: Manages claim status data in DynamoDB
- **S3Service**: Retrieves and stores claim notes in S3
- **BedrockService**: Invokes Amazon Bedrock to generate AI summaries

### AWS Permissions

The service requires the following IAM permissions:

- `dynamodb:GetItem`, `dynamodb:PutItem`, etc.
- `s3:GetObject`, `s3:PutObject`, `s3:ListBucket`
- `bedrock:InvokeModel`

## Configuration

Environment variables:

- `AWS_DEFAULT_REGION` - AWS region (default: us-east-1)
- `AWS:DynamoDb:TableName` - DynamoDB table name (default: claims)
- `AWS:S3:BucketName` - S3 bucket for claim notes (default: claim-notes)

## Deployment

### Local Development

```bash
# Restore dependencies
dotnet restore

# Build
dotnet build

# Run
dotnet run
```

Access Swagger UI: http://localhost:5000/swagger

### Docker

```bash
# Build image
docker build -t claim-status-api:latest .

# Run container
docker run -p 8080:8080 \
  -e AWS_DEFAULT_REGION=us-east-1 \
  claim-status-api:latest
```

### Kubernetes

```bash
# Deploy to EKS
scripts/deploy-claim-status-api.sh

# Check status
kubectl get pods -n materclaims -l app=claim-status-api

# View logs
kubectl logs -n materclaims -l app=claim-status-api -f

# Port forward for local testing
kubectl port-forward -n materclaims svc/claim-status-api 8080:80
```

## Security

- Non-root container user (UID 1000)
- Read-only root filesystem
- Security context restrictions
- AWS IAM role-based access (IRSA)
- S3 encryption at rest (AES256)
- S3 public access blocking

## Monitoring

- Health check endpoint: `/health`
- Structured logging with Serilog
- CloudWatch integration ready
- Pod anti-affinity for high availability

## Development

### Project Structure

```
claim-status-api/
├── Controllers/
│   └── ClaimsController.cs      # API endpoints
├── Models/
│   ├── ClaimStatus.cs           # Domain model
│   ├── ClaimSummary.cs          # Summary response
│   └── SummarizeRequest.cs       # Request model
├── Services/
│   ├── DynamoDbService.cs        # DynamoDB integration
│   ├── S3Service.cs              # S3 integration
│   └── BedrockService.cs         # Bedrock integration
├── Program.cs                    # Application setup
├── appsettings.json              # Configuration
└── Dockerfile                    # Container image
```

## Next Steps

1. Deploy infrastructure with Terraform
2. Create sample claims in DynamoDB
3. Upload claim notes to S3
4. Test endpoints with curl or Swagger UI
5. Monitor logs and metrics

## Support

For issues or questions, contact the insurance platform team.
