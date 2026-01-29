using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Amazon.DynamoDBv2.Model;
using ClaimStatusApi.Models;
using ClaimStatusApi.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;

namespace ClaimStatusApi.Tests;

[TestClass]
public class DynamoDbServiceTests
{
    private IConfiguration _config = null!;
    private ILogger<DynamoDbService> _logger = null!;

    [TestInitialize]
    public void Init()
    {
        _config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["AWS:DynamoDb:TableName"] = "claims"
        }).Build();
        _logger = Mock.Of<ILogger<DynamoDbService>>();
    }

    [TestMethod]
    public async Task GetClaimStatusAsync_ReturnsClaim_WhenItemExists()
    {
        var fakeClient = new FakeAmazonDynamoDbClient();
        var service = new DynamoDbService(fakeClient, _logger, _config);

        fakeClient.SeedItem(new Dictionary<string, AttributeValue>
        {
            ["id"] = new AttributeValue { S = "CID" },
            ["status"] = new AttributeValue { S = "Under Review" },
            ["claimType"] = new AttributeValue { S = "Property" },
            ["submissionDate"] = new AttributeValue { S = DateTime.UtcNow.ToString("O") },
            ["claimantName"] = new AttributeValue { S = "John" },
            ["amount"] = new AttributeValue { S = "123.45" },
            ["notesKey"] = new AttributeValue { S = "notes/key" }
        });

        var result = await service.GetClaimStatusAsync("CID");
        Assert.IsNotNull(result);
        Assert.AreEqual("CID", result!.Id);
    }

    [TestMethod]
    public async Task SaveClaimStatusAsync_CallsPutItem()
    {
        var fakeClient = new FakeAmazonDynamoDbClient();
        var service = new DynamoDbService(fakeClient, _logger, _config);

        var claim = new ClaimStatus
        {
            Id = "X",
            Status = "S",
            ClaimType = "T",
            SubmissionDate = DateTime.UtcNow,
            ClaimantName = "N",
            Amount = 10.5m,
            NotesKey = "nk"
        };

        await service.SaveClaimStatusAsync(claim);

        Assert.IsTrue(fakeClient.LastPutItemRequest != null);
        Assert.IsTrue(fakeClient.LastPutItemRequest.Item.ContainsKey("id"));
        Assert.AreEqual("X", fakeClient.LastPutItemRequest.Item["id"].S);
    }
}

// Minimal fake client that overrides needed async methods used by DocumentModel.Table
internal class FakeAmazonDynamoDbClient : Amazon.DynamoDBv2.AmazonDynamoDBClient
{
    private Dictionary<string, AttributeValue>? _seedItem;

    public Amazon.DynamoDBv2.Model.PutItemRequest? LastPutItemRequest { get; private set; }

    public void SeedItem(Dictionary<string, AttributeValue> item)
    {
        _seedItem = item;
    }

    // No DescribeTable override required after service refactor

    public override Task<Amazon.DynamoDBv2.Model.GetItemResponse> GetItemAsync(Amazon.DynamoDBv2.Model.GetItemRequest request, CancellationToken cancellationToken = default)
    {
        if (_seedItem != null && request.Key != null && request.Key.TryGetValue("id", out var idAttr) && _seedItem.TryGetValue("id", out _))
        {
            return Task.FromResult(new Amazon.DynamoDBv2.Model.GetItemResponse { Item = new Dictionary<string, AttributeValue>(_seedItem) });
        }

        return Task.FromResult(new Amazon.DynamoDBv2.Model.GetItemResponse { Item = new Dictionary<string, AttributeValue>() });
    }

    public override Task<Amazon.DynamoDBv2.Model.PutItemResponse> PutItemAsync(Amazon.DynamoDBv2.Model.PutItemRequest request, CancellationToken cancellationToken = default)
    {
        LastPutItemRequest = request;
        return Task.FromResult(new Amazon.DynamoDBv2.Model.PutItemResponse());
    }
}
