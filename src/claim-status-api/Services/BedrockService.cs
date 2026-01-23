using Amazon.BedrockRuntime;
using Amazon.BedrockRuntime.Model;
using ClaimStatusApi.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using System.Text;
using System.Text.Json;

namespace ClaimStatusApi.Services;

public class BedrockService : IBedrockService
{
    private readonly IAmazonBedrockRuntime _bedrockRuntime;
    private readonly ILogger<BedrockService> _logger;
    private readonly string _modelId;

    public BedrockService(IAmazonBedrockRuntime bedrockRuntime, ILogger<BedrockService> logger, IConfiguration config)
    {
        _bedrockRuntime = bedrockRuntime;
        _logger = logger;
        _modelId = config["AWS:Bedrock:ModelId"] ?? "anthropic.claude-3-haiku-20240307-v1:0";
    }

    public async Task<ClaimSummary> GenerateSummaryAsync(string claimId, string claimNotes)
    {
        try
        {
            var prompt = BuildPrompt(claimNotes);
            var response = await InvokeClaudeAsync(prompt);
            
            var summary = ParseSummaryResponse(response, claimId);
            _logger.LogInformation($"Successfully generated summary for claim {claimId}");
            
            return summary;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error generating summary for claim {claimId} using Bedrock");
            throw;
        }
    }

    private string BuildPrompt(string claimNotes)
    {
        return $@"Analyze the following insurance claim notes and provide structured summaries:

CLAIM NOTES:
{claimNotes}

Please provide your response in the following JSON format:
{{
    ""overall_summary"": ""A concise 2-3 sentence summary of the entire claim"",
    ""customer_facing_summary"": ""A professional, empathetic summary suitable for the customer (avoid jargon)"",
    ""adjuster_focused_summary"": ""A detailed technical summary for insurance adjusters with key facts and assessments"",
    ""recommended_next_step"": ""A specific recommended action for the insurance team to take next""
}}

Ensure the response is valid JSON that can be parsed.";
    }

    private async Task<string> InvokeClaudeAsync(string prompt)
    {
        var payload = JsonSerializer.Serialize(new
        {
            anthropic_version = "bedrock-2023-09-30",
            max_tokens = 1024,
            temperature = 0.7,
            messages = new[]
            {
                new
                {
                    role = "user",
                    content = new[]
                    {
                        new { type = "text", text = prompt }
                    }
                }
            }
        });

        var request = new InvokeModelRequest
        {
            ModelId = _modelId,
            ContentType = "application/json",
            Accept = "application/json",
            Body = new MemoryStream(Encoding.UTF8.GetBytes(payload))
        };

        var response = await _bedrockRuntime.InvokeModelAsync(request);
        
        using (var reader = new StreamReader(response.Body))
        {
            return await reader.ReadToEndAsync();
        }
    }

    private ClaimSummary ParseSummaryResponse(string response, string claimId)
    {
        try
        {
            using (var jsonDoc = JsonDocument.Parse(response))
            {
                var root = jsonDoc.RootElement;
                
                // Extract content from Bedrock response
                string extractedText = string.Empty;
                
                if (root.TryGetProperty("content", out var contentArray) && contentArray.ValueKind == System.Text.Json.JsonValueKind.Array)
                {
                    foreach (var item in contentArray.EnumerateArray())
                    {
                        if (item.TryGetProperty("text", out var textProp))
                        {
                            extractedText = textProp.GetString() ?? string.Empty;
                            break;
                        }
                    }
                }

                // Parse the extracted JSON from Claude
                var summaryJson = JsonDocument.Parse(extractedText);
                var summaryRoot = summaryJson.RootElement;

                return new ClaimSummary
                {
                    ClaimId = claimId,
                    OverallSummary = summaryRoot.GetProperty("overall_summary").GetString() ?? string.Empty,
                    CustomerFacingSummary = summaryRoot.GetProperty("customer_facing_summary").GetString() ?? string.Empty,
                    AdjusterFocusedSummary = summaryRoot.GetProperty("adjuster_focused_summary").GetString() ?? string.Empty,
                    RecommendedNextStep = summaryRoot.GetProperty("recommended_next_step").GetString() ?? string.Empty,
                    GeneratedAt = DateTime.UtcNow,
                    Model = _modelId
                };
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error parsing Bedrock response");
            throw;
        }
    }
}
