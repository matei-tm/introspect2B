using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Amazon.S3;
using Amazon.S3.Model;
using ClaimStatusApi.Services;
using Microsoft.Extensions.Logging;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;

namespace ClaimStatusApi.Integration.Tests;

/// <summary>
/// Integration tests for S3 service
/// These tests verify actual S3 operations using a real or simulated client
/// </summary>
[TestClass]
[TestCategory("Integration")]
public class S3IntegrationTests
{
    private ILogger<S3Service> _logger = null!;
    private const string TestBucket = "integration-test-bucket";

    [TestInitialize]
    public void Setup()
    {
        _logger = Mock.Of<ILogger<S3Service>>();
    }

    [TestMethod]
    public async Task SaveAndRetrieveNotes_EndToEnd_Success()
    {
        // Arrange
        var fakeS3Client = new IntegrationTestS3Client();
        var service = new S3Service(fakeS3Client, _logger);

        var testKey = "test-notes/claim-001.txt";
        var testContent = "This is a test claim note.\nIt contains multiple lines.\nFor integration testing.";

        // Act - Save notes
        await service.SaveClaimNotesAsync(TestBucket, testKey, testContent);

        // Act - Retrieve notes
        var retrievedContent = await service.GetClaimNotesAsync(TestBucket, testKey);

        // Assert
        Assert.IsNotNull(retrievedContent, "Retrieved content should not be null");
        Assert.AreEqual(testContent, retrievedContent);
    }

    [TestMethod]
    public async Task GetClaimNotes_NonExistentKey_ThrowsException()
    {
        // Arrange
        var fakeS3Client = new IntegrationTestS3Client();
        var service = new S3Service(fakeS3Client, _logger);

        // Act & Assert
        await Assert.ThrowsExceptionAsync<AmazonS3Exception>(
            () => service.GetClaimNotesAsync(TestBucket, "non-existent-key.txt"),
            "Should throw AmazonS3Exception for non-existent key"
        );
    }

    [TestMethod]
    public async Task SaveNotes_OverwritesExistingContent()
    {
        // Arrange
        var fakeS3Client = new IntegrationTestS3Client();
        var service = new S3Service(fakeS3Client, _logger);

        var testKey = "test-notes/claim-002.txt";
        var originalContent = "Original claim notes";
        var updatedContent = "Updated claim notes with more details";

        // Act - Save original
        await service.SaveClaimNotesAsync(TestBucket, testKey, originalContent);

        // Act - Overwrite with updated content
        await service.SaveClaimNotesAsync(TestBucket, testKey, updatedContent);

        // Act - Retrieve
        var retrievedContent = await service.GetClaimNotesAsync(TestBucket, testKey);

        // Assert
        Assert.AreEqual(updatedContent, retrievedContent, "Content should be updated");
        Assert.AreNotEqual(originalContent, retrievedContent, "Old content should be replaced");
    }

    [TestMethod]
    public async Task SaveMultipleNotes_AllPersisted()
    {
        // Arrange
        var fakeS3Client = new IntegrationTestS3Client();
        var service = new S3Service(fakeS3Client, _logger);

        var testNotes = new Dictionary<string, string>
        {
            ["notes/claim-101.txt"] = "Claim 101: Minor auto damage",
            ["notes/claim-102.txt"] = "Claim 102: Property water damage",
            ["notes/claim-103.txt"] = "Claim 103: Health insurance claim"
        };

        // Act - Save all notes
        foreach (var kvp in testNotes)
        {
            await service.SaveClaimNotesAsync(TestBucket, kvp.Key, kvp.Value);
        }

        // Assert - Retrieve and verify each
        foreach (var kvp in testNotes)
        {
            var retrieved = await service.GetClaimNotesAsync(TestBucket, kvp.Key);
            Assert.AreEqual(kvp.Value, retrieved, $"Content for {kvp.Key} should match");
        }
    }

    [TestMethod]
    public async Task SaveNotes_LargeContent_Success()
    {
        // Arrange
        var fakeS3Client = new IntegrationTestS3Client();
        var service = new S3Service(fakeS3Client, _logger);

        var testKey = "notes/large-claim.txt";
        
        // Generate large content (simulate detailed claim notes)
        var sb = new StringBuilder();
        for (int i = 0; i < 1000; i++)
        {
            sb.AppendLine($"Line {i}: Detailed claim investigation notes with timestamps {DateTime.UtcNow:O}");
        }
        var largeContent = sb.ToString();

        // Act
        await service.SaveClaimNotesAsync(TestBucket, testKey, largeContent);
        var retrievedContent = await service.GetClaimNotesAsync(TestBucket, testKey);

        // Assert
        Assert.AreEqual(largeContent.Length, retrievedContent.Length);
        Assert.AreEqual(largeContent, retrievedContent);
    }

    [TestMethod]
    public async Task SaveNotes_SpecialCharacters_PreservesContent()
    {
        // Arrange
        var fakeS3Client = new IntegrationTestS3Client();
        var service = new S3Service(fakeS3Client, _logger);

        var testKey = "notes/special-chars.txt";
        var specialContent = "Special chars: émojis 🎉, quotes \"test\", newlines\n\r, tabs\t, and symbols: <>&@#$%";

        // Act
        await service.SaveClaimNotesAsync(TestBucket, testKey, specialContent);
        var retrievedContent = await service.GetClaimNotesAsync(TestBucket, testKey);

        // Assert
        Assert.AreEqual(specialContent, retrievedContent);
    }
}

/// <summary>
/// Simulated S3 client for integration testing
/// This provides a more realistic simulation than simple mocks by using in-memory storage
/// In production, replace this with actual LocalStack or MinIO
/// </summary>
internal class IntegrationTestS3Client : AmazonS3Client
{
    private readonly Dictionary<string, Dictionary<string, byte[]>> _storage = new();

    public IntegrationTestS3Client() : base(new AmazonS3Config
    {
        ServiceURL = "http://localhost:4566", // LocalStack S3 URL (if available)
        ForcePathStyle = true,
        RegionEndpoint = Amazon.RegionEndpoint.USEast1
    })
    {
    }

    public override Task<GetObjectResponse> GetObjectAsync(GetObjectRequest request, CancellationToken cancellationToken = default)
    {
        if (_storage.TryGetValue(request.BucketName, out var bucket) && 
            bucket.TryGetValue(request.Key, out var data))
        {
            var response = new GetObjectResponse
            {
                ResponseStream = new MemoryStream(data),
                BucketName = request.BucketName,
                Key = request.Key,
                ContentLength = data.Length
            };
            return Task.FromResult(response);
        }

        throw new AmazonS3Exception($"The specified key does not exist: {request.Key}");
    }

    public override Task<PutObjectResponse> PutObjectAsync(PutObjectRequest request, CancellationToken cancellationToken = default)
    {
        if (!_storage.ContainsKey(request.BucketName))
        {
            _storage[request.BucketName] = new Dictionary<string, byte[]>();
        }

        byte[] data;
        if (!string.IsNullOrEmpty(request.ContentBody))
        {
            data = Encoding.UTF8.GetBytes(request.ContentBody);
        }
        else if (request.InputStream != null)
        {
            using var ms = new MemoryStream();
            request.InputStream.CopyTo(ms);
            data = ms.ToArray();
        }
        else
        {
            data = Array.Empty<byte>();
        }

        _storage[request.BucketName][request.Key] = data;

        return Task.FromResult(new PutObjectResponse
        {
            ETag = $"\"{Guid.NewGuid():N}\"",
            VersionId = Guid.NewGuid().ToString()
        });
    }
}
