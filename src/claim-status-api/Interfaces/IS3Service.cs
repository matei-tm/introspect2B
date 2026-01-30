namespace ClaimStatusApi.Interfaces;

public interface IS3Service
{
    Task<string> GetClaimNotesAsync(string bucketName, string key);
    Task SaveClaimNotesAsync(string bucketName, string key, string content);
}
