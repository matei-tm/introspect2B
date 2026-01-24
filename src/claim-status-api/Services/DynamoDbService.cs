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
            var table = DynamoTableFactory.BuildTable(_dynamoDb, _tableName);
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
            var table = DynamoTableFactory.BuildTable(_dynamoDb, _tableName);
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

internal static class DynamoTableFactory
{
    public static ITable BuildTable(IAmazonDynamoDB client, string tableName)
    {
#pragma warning disable CS0618
        // Prefer TableBuilder if available; fallback to LoadTable to preserve behavior.
        // New SDKs recommend using TableBuilder to construct Table with best-practice configuration.
        try
        {
            var builderType = typeof(Table).Assembly.GetType("Amazon.DynamoDBv2.DocumentModel.TableBuilder");
            if (builderType != null)
            {
                // Attempt to call: TableBuilder.Create(client, tableName).Build()
                var createMethod = builderType.GetMethod("Create", new[] { typeof(IAmazonDynamoDB), typeof(string) });
                if (createMethod != null)
                {
                    var builder = createMethod.Invoke(null, new object[] { client, tableName });
                    var buildMethod = builderType.GetMethod("Build");
                    if (buildMethod != null)
                    {
                        var table = (ITable?)buildMethod.Invoke(builder, Array.Empty<object>());
                        if (table != null)
                            return table;
                    }
                }
            }
        }
        catch
        {
            // Ignore reflection issues and use legacy path
        }

        return Table.LoadTable(client, tableName);
#pragma warning restore CS0618
    }
}
