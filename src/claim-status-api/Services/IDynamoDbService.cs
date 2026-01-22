using ClaimStatusApi.Models;

namespace ClaimStatusApi.Services;

public interface IDynamoDbService
{
    Task<ClaimStatus?> GetClaimStatusAsync(string claimId);
    Task SaveClaimStatusAsync(ClaimStatus claimStatus);
}
