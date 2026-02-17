---
layout: default
title: API Reference
---

# API Reference

The Claim Status API provides two primary endpoints for retrieving claim information and generating AI-powered summaries.

## Base URL

```
https://<api-gateway-id>.execute-api.us-east-1.amazonaws.com/prod
```

Or via port-forward for local testing:
```
http://localhost:8080
```

## Authentication

All API endpoints require **AWS_IAM authentication** (SigV4 signing).

### API Key (Optional)

The API Gateway deployment includes an API key for additional access control:

```bash
# Get API key
aws apigateway get-api-keys --include-values --query 'items[0].value' --output text

# Use in request header
curl -H "x-api-key: YOUR_API_KEY" https://...
```

## Endpoints

### GET /api/claims/{id}

Retrieve claim details from DynamoDB.

#### Parameters

| Name | Type | Location | Required | Description |
|------|------|----------|----------|-------------|
| `id` | string | path | Yes | Unique claim identifier |

#### Request Example

```bash
curl -X GET http://localhost:8080/api/claims/CLAIM-001
```

#### Response

**Status**: `200 OK`

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

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Claim identifier |
| `status` | string | Current claim status |
| `claimType` | string | Type of claim (Property, Auto, Health, etc.) |
| `submissionDate` | string (ISO 8601) | Date claim was submitted |
| `claimantName` | string | Name of claimant |
| `amount` | number | Claim amount in USD |
| `notesKey` | string | S3 key for detailed claim notes |

#### Error Responses

**Status**: `404 Not Found`
```json
{
  "error": "Claim not found",
  "claimId": "CLAIM-999"
}
```

**Status**: `500 Internal Server Error`
```json
{
  "error": "Failed to retrieve claim",
  "message": "DynamoDB service unavailable"
}
```

---

### POST /api/claims/{id}/summarize

Generate an AI-powered summary using Amazon Bedrock (Claude 3 Haiku).

#### Parameters

| Name | Type | Location | Required | Description |
|------|------|----------|----------|-------------|
| `id` | string | path | Yes | Unique claim identifier |
| `notesOverride` | string | body | No | Override notes from S3 (for testing) |
| `perspective` | string | body | No | Summary perspective: `customer`, `adjuster`, or `both` (default) |

#### Request Example

**Basic Request:**
```bash
curl -X POST http://localhost:8080/api/claims/CLAIM-001/summarize \
  -H "Content-Type: application/json" \
  -d '{}'
```

**With Notes Override:**
```bash
curl -X POST http://localhost:8080/api/claims/CLAIM-001/summarize \
  -H "Content-Type: application/json" \
  -d '{
    "notesOverride": "Customer reported water damage to kitchen after pipe burst. Estimated damage: $25,000. No previous claims."
  }'
```

**Specific Perspective:**
```bash
curl -X POST http://localhost:8080/api/claims/CLAIM-001/summarize \
  -H "Content-Type: application/json" \
  -d '{
    "perspective": "customer"
  }'
```

#### Response

**Status**: `200 OK`

```json
{
  "claimId": "CLAIM-001",
  "overallSummary": "Property damage claim for water damage in kitchen and dining room. Submitted on 2024-01-15 by John Doe for $25,000. Currently under review by claims adjuster.",
  "customerFacingSummary": "Your claim for water damage has been received and is being carefully reviewed by our team. We appreciate the detailed documentation you provided. An adjuster will contact you within 48 hours to schedule an inspection.",
  "adjusterFocusedSummary": "Water damage claim following pipe burst in kitchen. Claimant reports damage to kitchen cabinets, hardwood flooring in dining room, and ceiling drywall. Photos submitted show moderate water staining. Recommend on-site inspection to assess extent of structural damage and verify repair estimates. Check for mold growth given water intrusion timeframe.",
  "recommendedNextStep": "Schedule property inspection within 48 hours to assess water damage extent and verify repair estimates. Coordinate with preferred contractor for mold assessment if water exposure exceeded 24 hours.",
  "generatedAt": "2024-01-23T14:30:00Z",
  "model": "anthropic.claude-3-haiku-20240307-v1:0",
  "tokensUsed": {
    "input": 245,
    "output": 178
  }
}
```

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `claimId` | string | Claim identifier |
| `overallSummary` | string | High-level summary of the claim |
| `customerFacingSummary` | string | Summary appropriate for customer communication |
| `adjusterFocusedSummary` | string | Technical summary for insurance adjusters |
| `recommendedNextStep` | string | AI-suggested next action |
| `generatedAt` | string (ISO 8601) | Timestamp of summary generation |
| `model` | string | Bedrock model identifier used |
| `tokensUsed` | object | Token usage statistics (input/output) |

#### Error Responses

**Status**: `404 Not Found`
```json
{
  "error": "Claim not found",
  "claimId": "CLAIM-999"
}
```

**Status**: `429 Too Many Requests`
```json
{
  "error": "Bedrock throttling error",
  "message": "Model invocation rate exceeded. Please retry after a few seconds."
}
```

**Status**: `500 Internal Server Error`
```json
{
  "error": "Failed to generate summary",
  "message": "Bedrock service error: Invalid model ID"
}
```

---

### GET /health

Kubernetes health check endpoint.

#### Request Example

```bash
curl http://localhost:8080/health
```

#### Response

**Status**: `200 OK`

```json
{
  "status": "Healthy",
  "checks": {
    "dynamodb": "OK",
    "s3": "OK",
    "bedrock": "OK"
  },
  "timestamp": "2024-01-23T14:30:00Z"
}
```

---

### GET /swagger

Interactive API documentation (Swagger UI).

Access via browser:
```
http://localhost:8080/swagger
```

---

## Sample Data

The deployment includes **8 sample claims** and **4 detailed note blobs**:

### Available Claim IDs

| Claim ID | Type | Status | Amount | Notes Key |
|----------|------|--------|--------|-----------|
| `CLAIM-001` | Property | Under Review | $25,000 | `claims/CLAIM-001/notes.txt` |
| `CLAIM-002` | Auto | Approved | $8,500 | `claims/CLAIM-002/notes.txt` |
| `CLAIM-003` | Health | Pending Documents | $12,300 | `claims/CLAIM-003/notes.txt` |
| `CLAIM-004` | Property | Rejected | $45,000 | `claims/CLAIM-004/notes.txt` |
| `CLAIM-005` | Auto | Under Review | $3,200 | None |
| `CLAIM-006` | Health | Approved | $6,750 | None |
| `CLAIM-007` | Property | Investigation | $18,900 | None |
| `CLAIM-008` | Auto | Closed | $5,100 | None |

### Initialize Sample Data

```bash
./scripts/init-sample-data.sh
```

---

## Rate Limits

### API Gateway

- **Default**: 10,000 requests/second
- **Burst**: 5,000 requests
- **Quota**: Can be customized per API key

### Amazon Bedrock

- **Claude 3 Haiku**: 1,000 tokens/minute (default)
- **Request Quota**: Request increase via AWS Support for production workloads

### Recommendations

- Implement client-side retry logic with exponential backoff
- Cache Bedrock summaries to reduce API calls
- Monitor CloudWatch metrics for throttling events

---

## Testing with cURL

### Complete Workflow Example

```bash
# 1. Get claim details
CLAIM_ID="CLAIM-001"
curl http://localhost:8080/api/claims/$CLAIM_ID | jq '.'

# 2. Generate AI summary
curl -X POST http://localhost:8080/api/claims/$CLAIM_ID/summarize \
  -H "Content-Type: application/json" | jq '.'

# 3. Check health
curl http://localhost:8080/health | jq '.'
```

### Testing All Sample Claims

```bash
for ID in CLAIM-001 CLAIM-002 CLAIM-003 CLAIM-004 CLAIM-005 CLAIM-006 CLAIM-007 CLAIM-008; do
  echo "Testing $ID..."
  curl -s http://localhost:8080/api/claims/$ID | jq '.id, .status, .claimType'
  echo ""
done
```

---

## Testing with Postman

### Import Collection

Download the Postman collection:
```bash
curl -O https://raw.githubusercontent.com/matei-tm/introspect2B/main/docs/postman-collection.json
```

### Environment Variables

Set the following variables in Postman:
- `base_url`: `http://localhost:8080` or your API Gateway URL
- `claim_id`: `CLAIM-001` (or any valid claim ID)

---

## Testing with Bruno

Bruno API test files are available in `src/bruno/api_tests/`:

```
src/bruno/api_tests/
├── get-claim.bru
├── summarize-claim.bru
└── health-check.bru
```

Run tests:
```bash
cd src/bruno
bruno run api_tests/
```

---

## CloudWatch Metrics

The API publishes custom CloudWatch metrics:

| Metric Name | Namespace | Description |
|-------------|-----------|-------------|
| `ApiRequestDuration` | `ClaimStatusApi` | Request duration in milliseconds |
| `BedrockInvocationDuration` | `ClaimStatusApi` | Bedrock invocation time |
| `SuccessfulRequests` | `ClaimStatusApi` | Count of successful API calls |
| `FailedRequests` | `ClaimStatusApi` | Count of failed API calls |

Query metrics:
```bash
aws cloudwatch get-metric-statistics \
  --namespace ClaimStatusApi \
  --metric-name ApiRequestDuration \
  --start-time 2024-01-23T00:00:00Z \
  --end-time 2024-01-23T23:59:59Z \
  --period 3600 \
  --statistics Average,Maximum \
  --region us-east-1
```

---

## Error Handling

All errors return a consistent format:

```json
{
  "error": "Error type",
  "message": "Detailed error message",
  "claimId": "CLAIM-XXX" (if applicable),
  "timestamp": "2024-01-23T14:30:00Z"
}
```

### HTTP Status Codes

| Code | Meaning | Common Causes |
|------|---------|---------------|
| 200 | OK | Request succeeded |
| 404 | Not Found | Claim ID doesn't exist |
| 429 | Too Many Requests | Rate limit or Bedrock throttling |
| 500 | Internal Server Error | DynamoDB, S3, or Bedrock service error |
| 503 | Service Unavailable | Downstream service temporarily unavailable |

---

## Related Documentation

- [Getting Started Guide](getting-started) - Deploy the API
- [Architecture Overview](architecture/overview) - System design
- [Intelligent Autoscaling](features/intelligent-autoscaling) - How autoscaling works

---

**Questions?** Open an issue on [GitHub](https://github.com/matei-tm/introspect2B/issues) or check the [Getting Started Guide](getting-started).
