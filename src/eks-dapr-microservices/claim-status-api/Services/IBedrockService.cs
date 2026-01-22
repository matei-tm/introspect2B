using ClaimStatusApi.Models;

namespace ClaimStatusApi.Services;

public interface IBedrockService
{
    Task<ClaimSummary> GenerateSummaryAsync(string claimId, string claimNotes);
}
