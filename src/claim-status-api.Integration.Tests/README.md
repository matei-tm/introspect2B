# Claim Status API - Integration Tests

This project contains integration tests for the Claim Status API. Integration tests verify end-to-end functionality with real or simulated AWS services.

## Purpose

Integration tests differ from unit tests by:
- Testing actual API endpoints using `WebApplicationFactory`
- Connecting to real AWS services or local simulations (LocalStack, DynamoDB Local)
- Verifying complete workflows across multiple components
- Testing service integrations (DynamoDB, S3, Bedrock)

## Running Integration Tests

### Run all tests (unit + integration)
```bash
dotnet test ../../introspect2B.sln
```

### Run only integration tests
```bash
dotnet test ../../introspect2B.sln --filter "TestCategory=Integration"
```

### Run only unit tests (exclude integration)
```bash
dotnet test ../../introspect2B.sln --filter "TestCategory!=Integration"
```

### Run with coverage
```bash
dotnet test ../../introspect2B.sln --filter "TestCategory=Integration" --collect:"XPlat Code Coverage"
```

## Test Categories

All tests in this project are marked with `[TestCategory("Integration")]` attribute to enable selective test execution.

## Test Structure

Integration tests should verify:
- ✅ API endpoints respond correctly
- ✅ DynamoDB read/write operations
- ✅ S3 object storage operations
- ✅ Bedrock AI inference calls
- ✅ End-to-end claim processing workflows
- ✅ Error handling and resilience

## Local Testing with LocalStack

For testing against AWS services locally, you can use LocalStack:

```bash
# Start LocalStack
docker run -d -p 4566:4566 localstack/localstack

# Configure AWS credentials for LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566

# Run integration tests
dotnet test --filter "TestCategory=Integration"
```

## Dependencies

- **Microsoft.AspNetCore.Mvc.Testing**: For testing API endpoints
- **MSTest**: Test framework
- **Moq**: Mocking framework (for selective mocking in integration tests)
- **AWS SDK**: For interacting with AWS services

## Future Enhancements

- [ ] Add WebApplicationFactory-based API endpoint tests
- [ ] Add DynamoDB Local integration tests
- [ ] Add S3 LocalStack integration tests
- [ ] Add Bedrock mock/simulation tests
- [ ] Add performance/load integration tests
- [ ] Add container-based test fixtures
