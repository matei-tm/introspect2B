using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.Model;
using ClaimStatusApi.Models;
using ClaimStatusApi.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;

namespace ClaimStatusApi.Integration.Tests;

/// <summary>
/// Integration tests for DynamoDB service
/// These tests verify actual DynamoDB operations using a real or simulated client
/// </summary>
[TestClass]
[TestCategory("Integration")]
public class DynamoDbIntegrationTests
{
    private ILogger<DynamoDbService> _logger = null!;
    private IConfiguration _config = null!;

    [TestInitialize]
    public void Setup()
    {
        _logger = Mock.Of<ILogger<DynamoDbService>>();
        
        var configValues = new Dictionary<string, string?>
        {
            ["AWS:DynamoDb:TableName"] = "claims-integration-test"
        };
        _config = new ConfigurationBuilder()
            .AddInMemoryCollection(configValues)
            .Build();
    }

    [TestMethod]
    public async Task SaveAndRetrieveClaim_EndToEnd_Success()
    {
        // Arrange
        var fakeClient = new IntegrationTestDynamoDbClient();
        var service = new DynamoDbService(fakeClient, _logger, _config);

        var testClaim = new ClaimStatus
        {
            Id = "INT-TEST-001",
            Status = "Under Review",
            ClaimType = "Auto",
            SubmissionDate = DateTime.UtcNow,
            ClaimantName = "Integration Test User",
            Amount = 5000.00m,
            NotesKey = "notes/integration-test-001.txt"
        };

        // Act - Save claim
        await service.SaveClaimStatusAsync(testClaim);

        // Act - Retrieve claim
        var retrievedClaim = await service.GetClaimStatusAsync(testClaim.Id);

        // Assert
        Assert.IsNotNull(retrievedClaim, "Retrieved claim should not be null");
        Assert.AreEqual(testClaim.Id, retrievedClaim.Id);
        Assert.AreEqual(testClaim.Status, retrievedClaim.Status);
        Assert.AreEqual(testClaim.ClaimType, retrievedClaim.ClaimType);
        Assert.AreEqual(testClaim.ClaimantName, retrievedClaim.ClaimantName);
        Assert.AreEqual(testClaim.Amount, retrievedClaim.Amount);
        Assert.AreEqual(testClaim.NotesKey, retrievedClaim.NotesKey);
    }

    [TestMethod]
    public async Task GetClaimStatus_NonExistentClaim_ReturnsNull()
    {
        // Arrange
        var fakeClient = new IntegrationTestDynamoDbClient();
        var service = new DynamoDbService(fakeClient, _logger, _config);

        // Act
        var result = await service.GetClaimStatusAsync("NON-EXISTENT-CLAIM");

        // Assert
        Assert.IsNull(result, "Non-existent claim should return null");
    }

    [TestMethod]
    public async Task UpdateClaim_ModifiesExistingData()
    {
        // Arrange
        var fakeClient = new IntegrationTestDynamoDbClient();
        var service = new DynamoDbService(fakeClient, _logger, _config);

        var originalClaim = new ClaimStatus
        {
            Id = "INT-TEST-002",
            Status = "Pending",
            ClaimType = "Property",
            SubmissionDate = DateTime.UtcNow,
            ClaimantName = "John Doe",
            Amount = 1000.00m,
            NotesKey = "notes/002.txt"
        };

        await service.SaveClaimStatusAsync(originalClaim);

        // Act - Update claim with new status
        var updatedClaim = new ClaimStatus
        {
            Id = "INT-TEST-002",
            Status = "Approved", // Changed
            ClaimType = "Property",
            SubmissionDate = originalClaim.SubmissionDate,
            ClaimantName = "John Doe",
            Amount = 1200.00m, // Changed
            NotesKey = "notes/002.txt"
        };

        await service.SaveClaimStatusAsync(updatedClaim);

        // Retrieve and verify
        var retrievedClaim = await service.GetClaimStatusAsync("INT-TEST-002");

        // Assert
        Assert.IsNotNull(retrievedClaim);
        Assert.AreEqual("Approved", retrievedClaim.Status);
        Assert.AreEqual(1200.00m, retrievedClaim.Amount);
    }

    [TestMethod]
    public async Task SaveMultipleClaims_AllPersisted()
    {
        // Arrange
        var fakeClient = new IntegrationTestDynamoDbClient();
        var service = new DynamoDbService(fakeClient, _logger, _config);

        var claims = new[]
        {
            new ClaimStatus { Id = "BULK-001", Status = "Pending", ClaimType = "Auto", SubmissionDate = DateTime.UtcNow, ClaimantName = "User1", Amount = 100m, NotesKey = "n1" },
            new ClaimStatus { Id = "BULK-002", Status = "Approved", ClaimType = "Property", SubmissionDate = DateTime.UtcNow, ClaimantName = "User2", Amount = 200m, NotesKey = "n2" },
            new ClaimStatus { Id = "BULK-003", Status = "Rejected", ClaimType = "Health", SubmissionDate = DateTime.UtcNow, ClaimantName = "User3", Amount = 300m, NotesKey = "n3" }
        };

        // Act - Save all claims
        foreach (var claim in claims)
        {
            await service.SaveClaimStatusAsync(claim);
        }

        // Assert - Retrieve and verify each
        foreach (var claim in claims)
        {
            var retrieved = await service.GetClaimStatusAsync(claim.Id);
            Assert.IsNotNull(retrieved, $"Claim {claim.Id} should be retrievable");
            Assert.AreEqual(claim.Status, retrieved.Status);
            Assert.AreEqual(claim.Amount, retrieved.Amount);
        }
    }
}

/// <summary>
/// Simulated DynamoDB client for integration testing
/// This provides a more realistic simulation than simple mocks by using in-memory storage
/// In production, replace this with actual DynamoDB Local or LocalStack
/// </summary>
internal class IntegrationTestDynamoDbClient : AmazonDynamoDBClient
{
    private readonly Dictionary<string, Dictionary<string, AttributeValue>> _storage = new();

    public IntegrationTestDynamoDbClient() : base(new AmazonDynamoDBConfig
    {
        ServiceURL = "http://localhost:8000", // DynamoDB Local URL (if available)
        RegionEndpoint = Amazon.RegionEndpoint.USEast1
    })
    {
    }

    public override Task<GetItemResponse> GetItemAsync(GetItemRequest request, System.Threading.CancellationToken cancellationToken = default)
    {
        if (request.Key.TryGetValue("id", out var idAttr) && _storage.TryGetValue(idAttr.S, out var item))
        {
            return Task.FromResult(new GetItemResponse
            {
                Item = new Dictionary<string, AttributeValue>(item)
            });
        }

        return Task.FromResult(new GetItemResponse
        {
            Item = new Dictionary<string, AttributeValue>()
        });
    }

    public override Task<PutItemResponse> PutItemAsync(PutItemRequest request, System.Threading.CancellationToken cancellationToken = default)
    {
        if (request.Item.TryGetValue("id", out var idAttr))
        {
            _storage[idAttr.S] = new Dictionary<string, AttributeValue>(request.Item);
        }

        return Task.FromResult(new PutItemResponse());
    }
}
