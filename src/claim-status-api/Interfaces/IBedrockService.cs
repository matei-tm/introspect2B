using ClaimStatusApi.Models;

namespace ClaimStatusApi.Interfaces;

public interface IBedrockService
{
    Task<ClaimSummary> GenerateSummaryAsync(string claimId, string claimNotes);
}
