using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DocumentModel;
using Amazon.DynamoDBv2.Model;
using ClaimStatusApi.Models;
using Microsoft.Extensions.Logging;

namespace ClaimStatusApi.Services;

public class DynamoDbService : IDynamoDbService
{
    private readonly IAmazonDynamoDB _dynamoDb;
    private readonly ILogger<DynamoDbService> _logger;
    private readonly string _tableName;

    public DynamoDbService(IAmazonDynamoDB dynamoDb, ILogger<DynamoDbService> logger, IConfiguration config)
    {
        _dynamoDb = dynamoDb;
        _logger = logger;
        _tableName = config["AWS:DynamoDb:TableName"] ?? "claims";
    }

    public async Task<ClaimStatus?> GetClaimStatusAsync(string claimId)
    {
        try
        {
            var getReq = new GetItemRequest
            {
                TableName = _tableName,
                Key = new Dictionary<string, AttributeValue>
                {
                    ["id"] = new AttributeValue { S = claimId }
                }
            };

            var getResp = await _dynamoDb.GetItemAsync(getReq);
            if (getResp.Item == null || getResp.Item.Count == 0)
            {
                _logger.LogWarning($"Claim {claimId} not found in DynamoDB");
                return null;
            }

            var item = getResp.Item;
            return new ClaimStatus
            {
                Id = item["id"].S,
                Status = item.TryGetValue("status", out var status) ? status.S : string.Empty,
                ClaimType = item.TryGetValue("claimType", out var ctype) ? ctype.S : string.Empty,
                SubmissionDate = item.TryGetValue("submissionDate", out var sdate) ? DateTime.Parse(sdate.S) : DateTime.MinValue,
                ClaimantName = item.TryGetValue("claimantName", out var cname) ? cname.S : string.Empty,
                Amount = item.TryGetValue("amount", out var amount) ? decimal.Parse(amount.S) : 0m,
                NotesKey = item.TryGetValue("notesKey", out var nkey) ? nkey.S : string.Empty
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error retrieving claim {claimId} from DynamoDB");
            throw;
        }
    }

    public async Task SaveClaimStatusAsync(ClaimStatus claimStatus)
    {
        try
        {
            var putReq = new PutItemRequest
            {
                TableName = _tableName,
                Item = new Dictionary<string, AttributeValue>
                {
                    ["id"] = new AttributeValue { S = claimStatus.Id },
                    ["status"] = new AttributeValue { S = claimStatus.Status },
                    ["claimType"] = new AttributeValue { S = claimStatus.ClaimType },
                    ["submissionDate"] = new AttributeValue { S = claimStatus.SubmissionDate.ToUniversalTime().ToString("O") },
                    ["claimantName"] = new AttributeValue { S = claimStatus.ClaimantName },
                    ["amount"] = new AttributeValue { S = claimStatus.Amount.ToString() },
                    ["notesKey"] = new AttributeValue { S = claimStatus.NotesKey }
                }
            };

            await _dynamoDb.PutItemAsync(putReq);
            _logger.LogInformation($"Claim {claimStatus.Id} saved to DynamoDB");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error saving claim {claimStatus.Id} to DynamoDB");
            throw;
        }
    }
}
