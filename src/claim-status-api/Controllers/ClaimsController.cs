using ClaimStatusApi.Models;
using ClaimStatusApi.Services;
using Microsoft.AspNetCore.Mvc;

namespace ClaimStatusApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ClaimsController : ControllerBase
{
    private readonly IDynamoDbService _dynamoDbService;
    private readonly IS3Service _s3Service;
    private readonly IBedrockService _bedrockService;
    private readonly ILogger<ClaimsController> _logger;
    private readonly IConfiguration _config;

    public ClaimsController(
        IDynamoDbService dynamoDbService,
        IS3Service s3Service,
        IBedrockService bedrockService,
        ILogger<ClaimsController> logger,
        IConfiguration config)
    {
        _dynamoDbService = dynamoDbService;
        _s3Service = s3Service;
        _bedrockService = bedrockService;
        _logger = logger;
        _config = config;
    }

    /// <summary>
    /// Get claim status information from DynamoDB
    /// </summary>
    /// <param name="id">The claim ID</param>
    /// <returns>Claim status information</returns>
    [HttpGet("{id}")]
    [ProduceResponseType(typeof(ClaimStatus), StatusCodes.Status200OK)]
    [ProduceResponseType(StatusCodes.Status404NotFound)]
    [ProduceResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<ClaimStatus>> GetClaim(string id)
    {
        try
        {
            _logger.LogInformation($"Getting claim status for ID: {id}");
            
            var claimStatus = await _dynamoDbService.GetClaimStatusAsync(id);
            
            if (claimStatus == null)
            {
                _logger.LogWarning($"Claim not found: {id}");
                return NotFound(new { message = $"Claim {id} not found" });
            }

            return Ok(claimStatus);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error retrieving claim {id}");
            return StatusCode(500, new { message = "Error retrieving claim status", error = ex.Message });
        }
    }

    /// <summary>
    /// Generate AI-powered summaries for a claim
    /// </summary>
    /// <param name="id">The claim ID</param>
    /// <param name="request">Optional request with custom notes</param>
    /// <returns>Claim summaries from Bedrock</returns>
    [HttpPost("{id}/summarize")]
    [ProduceResponseType(typeof(ClaimSummary), StatusCodes.Status200OK)]
    [ProduceResponseType(StatusCodes.Status404NotFound)]
    [ProduceResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<ClaimSummary>> SummarizeClaim(string id, [FromBody] SummarizeRequest? request = null)
    {
        try
        {
            _logger.LogInformation($"Generating summary for claim ID: {id}");
            
            // Get claim status
            var claimStatus = await _dynamoDbService.GetClaimStatusAsync(id);
            if (claimStatus == null)
            {
                _logger.LogWarning($"Claim not found: {id}");
                return NotFound(new { message = $"Claim {id} not found" });
            }

            // Get claim notes from S3 or use provided notes
            string claimNotes;
            if (!string.IsNullOrEmpty(request?.NotesOverride))
            {
                claimNotes = request.NotesOverride;
                _logger.LogInformation($"Using provided claim notes for claim {id}");
            }
            else
            {
                var bucketName = _config["AWS:S3:BucketName"] ?? "claim-notes";
                claimNotes = await _s3Service.GetClaimNotesAsync(bucketName, claimStatus.NotesKey);
            }

            // Generate summary using Bedrock
            var summary = await _bedrockService.GenerateSummaryAsync(id, claimNotes);

            _logger.LogInformation($"Successfully generated summary for claim {id}");
            return Ok(summary);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error generating summary for claim {id}");
            return StatusCode(500, new { message = "Error generating claim summary", error = ex.Message });
        }
    }
}
