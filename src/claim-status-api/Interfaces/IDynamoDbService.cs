using ClaimStatusApi.Models;

namespace ClaimStatusApi.Interfaces;

public interface IDynamoDbService
{
    Task<ClaimStatus?> GetClaimStatusAsync(string claimId);
    Task SaveClaimStatusAsync(ClaimStatus claimStatus);
}
