# Claim Status API Testing

This folder contains k6 test scenarios for both integration testing and performance testing, executed from AWS CodeBuild.

## Test Files

### environment-integration-test.js
**Purpose:** Quick API validation with minimal load  
**Stage:** IntegrationTest (runs after Docker build)  
**Duration:** 30 seconds  
**Load:** 1 virtual user  
**Validates:**
- Health endpoint availability
- GET /api/claims/{claimId} functionality
- POST /api/claims/{claimId}/summarize Bedrock integration
- JSON response validity
- Basic response times (<5s p95)

**Success Criteria:**
- <5% request failures
- 95% of checks pass

### performance-test.js
**Purpose:** Stress test API under realistic load  
**Stage:** PerformanceTest (runs after IntegrationTest passes)  
**Duration:** 5 minutes  
**Load:** Ramps 1m→10 VUs, sustains 3m@30 VUs, ramps down 1m→0  
**Tests:**
- Concurrent GET requests
- Concurrent POST requests with Bedrock
- Response time under load (<500ms p95 for GET, <3s for POST)
- Error rate under load

**Success Criteria:**
- 99% of checks pass
- p95 response times within thresholds

## Running Tests Locally

### Integration Test
```bash
export BASE_URL="https://your-api-gateway-url.amazonaws.com/dev"
export API_KEY="your-api-key"
k6 run environment-integration-test.js
```

### Performance Test
```bash
export BASE_URL="https://your-api-gateway-url.amazonaws.com/dev"
export API_KEY="your-api-key"
k6 run performance-test.js
```

## Pipeline Flow

```
IntegrationTest Stage:
  1. SeedData → Populate DynamoDB with test data
  2. IntegrationCheck → Run environment-integration-test.js (1 VU, 30s)

PerformanceTest Stage:
  1. LoadTest → Run performance-test.js (up to 30 VUs, 5 min)
```

## Benefits

- **Fast Feedback:** Integration tests (30s) fail fast if APIs are broken
- **Cost Efficient:** Only run expensive performance tests if integration passes
- **Clear Separation:** Functionality vs. scalability issues
- **Separate Metrics:** Track functional health and performance separately
