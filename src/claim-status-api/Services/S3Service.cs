using Amazon.S3;
using Amazon.S3.Model;
using Microsoft.Extensions.Logging;
using ClaimStatusApi.Interfaces;

namespace ClaimStatusApi.Services;

public class S3Service : IS3Service
{
    private readonly IAmazonS3 _s3Client;
    private readonly ILogger<S3Service> _logger;

    public S3Service(IAmazonS3 s3Client, ILogger<S3Service> logger)
    {
        _s3Client = s3Client;
        _logger = logger;
    }

    public async Task<string> GetClaimNotesAsync(string bucketName, string key)
    {
        try
        {
            var request = new GetObjectRequest
            {
                BucketName = bucketName,
                Key = key
            };

            using (var response = await _s3Client.GetObjectAsync(request))
            using (var reader = new StreamReader(response.ResponseStream))
            {
                var content = await reader.ReadToEndAsync();
                _logger.LogInformation($"Retrieved claim notes from S3: s3://{bucketName}/{key}");
                return content;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error retrieving claim notes from S3: s3://{bucketName}/{key}");
            throw;
        }
    }

    public async Task SaveClaimNotesAsync(string bucketName, string key, string content)
    {
        try
        {
            var request = new PutObjectRequest
            {
                BucketName = bucketName,
                Key = key,
                ContentBody = content,
                ContentType = "text/plain"
            };

            await _s3Client.PutObjectAsync(request);
            _logger.LogInformation($"Saved claim notes to S3: s3://{bucketName}/{key}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error saving claim notes to S3: s3://{bucketName}/{key}");
            throw;
        }
    }
}
