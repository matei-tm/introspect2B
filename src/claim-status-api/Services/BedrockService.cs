using Amazon.BedrockRuntime;
using Amazon.BedrockRuntime.Model;
using ClaimStatusApi.Models;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using System.Collections.Generic;
using System.Text;
using System.Text.Json;

namespace ClaimStatusApi.Services;

public class BedrockService : IBedrockService
{
    private readonly IAmazonBedrockRuntime _bedrockRuntime;
    private readonly ILogger<BedrockService> _logger;
    private readonly string _modelId;
    private readonly string _inferenceProfileId;
    private readonly string _inferenceProfileArn;

    public BedrockService(IAmazonBedrockRuntime bedrockRuntime, ILogger<BedrockService> logger, IConfiguration config)
    {
        _bedrockRuntime = bedrockRuntime;
        _logger = logger;
        _modelId = config["AWS:Bedrock:ModelId"] ?? "anthropic.claude-3-haiku-20240307-v1:0";
        _inferenceProfileId = config["AWS:Bedrock:InferenceProfileId"] ?? string.Empty;
        _inferenceProfileArn = config["AWS:Bedrock:InferenceProfileArn"] ?? string.Empty;
    }

    public async Task<ClaimSummary> GenerateSummaryAsync(string claimId, string claimNotes)
    {
        try
        {
            var prompt = BuildPrompt(claimNotes);
            var target = !string.IsNullOrWhiteSpace(_inferenceProfileId)
                ? _inferenceProfileId
                : (!string.IsNullOrWhiteSpace(_inferenceProfileArn) ? _inferenceProfileArn : _modelId);
            _logger.LogInformation("Invoking Bedrock target {Target} for claim {ClaimId}", target, claimId);
            var responseText = await InvokeConverseAsync(prompt);
            
            var summary = ParseSummaryResponse(responseText, claimId);
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

    private async Task<string> InvokeConverseAsync(string prompt)
    {
        var target = !string.IsNullOrWhiteSpace(_inferenceProfileId)
            ? _inferenceProfileId
            : (!string.IsNullOrWhiteSpace(_inferenceProfileArn) ? _inferenceProfileArn : _modelId);
        var request = new Amazon.BedrockRuntime.Model.ConverseRequest
        {
            ModelId = target,
            Messages = new List<Amazon.BedrockRuntime.Model.Message>
            {
                new Amazon.BedrockRuntime.Model.Message
                {
                    Role = "user",
                    Content = new List<Amazon.BedrockRuntime.Model.ContentBlock>
                    {
                        new Amazon.BedrockRuntime.Model.ContentBlock { Text = prompt }
                    }
                }
            }
        };

        var response = await _bedrockRuntime.ConverseAsync(request);

        // Extract the generated text from the Converse response
        var outputMessage = response.Output?.Message;
        if (outputMessage?.Content != null)
        {
            foreach (var block in outputMessage.Content)
            {
                if (!string.IsNullOrEmpty(block.Text))
                {
                    return block.Text;
                }
            }
        }

        _logger.LogWarning("Converse returned no text for target {Target}", target);
        return string.Empty;
    }

    private ClaimSummary ParseSummaryResponse(string responseText, string claimId)
    {
        try
        {
            var jsonPayload = ExtractJsonPayload(responseText);
            var summaryJson = JsonDocument.Parse(jsonPayload);
            var summaryRoot = summaryJson.RootElement;

            return new ClaimSummary
            {
                ClaimId = claimId,
                OverallSummary = summaryRoot.GetProperty("overall_summary").GetString() ?? string.Empty,
                CustomerFacingSummary = summaryRoot.GetProperty("customer_facing_summary").GetString() ?? string.Empty,
                AdjusterFocusedSummary = summaryRoot.GetProperty("adjuster_focused_summary").GetString() ?? string.Empty,
                RecommendedNextStep = summaryRoot.GetProperty("recommended_next_step").GetString() ?? string.Empty,
                GeneratedAt = DateTime.UtcNow,
                Model = !string.IsNullOrWhiteSpace(_inferenceProfileId)
                    ? _inferenceProfileId
                    : (!string.IsNullOrWhiteSpace(_inferenceProfileArn) ? _inferenceProfileArn : _modelId)
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error parsing Bedrock response");
            throw;
        }
    }

    private static string ExtractJsonPayload(string text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return "{}";
        }

        var trimmed = text.Trim();

        // Handle fenced code blocks like ```json ... ```
        if (trimmed.StartsWith("```", StringComparison.Ordinal))
        {
            int firstFence = trimmed.IndexOf("```", StringComparison.Ordinal);
            int secondFence = trimmed.IndexOf("```", firstFence + 3, StringComparison.Ordinal);
            if (secondFence > firstFence)
            {
                var inner = trimmed.Substring(firstFence + 3, secondFence - (firstFence + 3)).Trim();
                // Remove optional language tag (e.g., 'json') at the start
                if (inner.StartsWith("json", StringComparison.OrdinalIgnoreCase))
                {
                    inner = inner.Substring(4).Trim();
                }
                return inner;
            }
        }

        // Fallback: extract between first '{' and last '}'
        int start = trimmed.IndexOf('{');
        int end = trimmed.LastIndexOf('}');
        if (start >= 0 && end > start)
        {
            return trimmed.Substring(start, end - start + 1);
        }

        // As a last resort, return the original trimmed text
        return trimmed;
    }
}
