using Amazon.DynamoDBv2;
using Amazon.DynamoDBv2.DocumentModel;
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
            var table = Table.LoadTable(_dynamoDb, _tableName);
            var document = await table.GetItemAsync(claimId);

            if (document == null)
            {
                _logger.LogWarning($"Claim {claimId} not found in DynamoDB");
                return null;
            }

            return new ClaimStatus
            {
                Id = document["id"].AsString(),
                Status = document["status"].AsString(),
                ClaimType = document["claimType"].AsString(),
                SubmissionDate = DateTime.Parse(document["submissionDate"].AsString()),
                ClaimantName = document["claimantName"].AsString(),
                Amount = decimal.Parse(document["amount"].AsString()),
                NotesKey = document["notesKey"].AsString()
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
            var table = Table.LoadTable(_dynamoDb, _tableName);
            var document = new Document
            {
                ["id"] = claimStatus.Id,
                ["status"] = claimStatus.Status,
                ["claimType"] = claimStatus.ClaimType,
                ["submissionDate"] = claimStatus.SubmissionDate.ToUniversalTime().ToString("O"),
                ["claimantName"] = claimStatus.ClaimantName,
                ["amount"] = claimStatus.Amount.ToString(),
                ["notesKey"] = claimStatus.NotesKey
            };

            await table.PutItemAsync(document);
            _logger.LogInformation($"Claim {claimStatus.Id} saved to DynamoDB");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error saving claim {claimStatus.Id} to DynamoDB");
            throw;
        }
    }
}
