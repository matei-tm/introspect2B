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

namespace ClaimStatusApi.Tests;

[TestClass]
public class S3ServiceTests
{
    [TestMethod]
    public async Task GetClaimNotesAsync_ReturnsContent()
    {
        var bucket = "b";
        var key = "k";
        var content = "hello from s3";

        var getResp = new GetObjectResponse
        {
            ResponseStream = new MemoryStream(Encoding.UTF8.GetBytes(content))
        };

        var s3Mock = new Mock<IAmazonS3>();
        s3Mock.Setup(s => s.GetObjectAsync(It.Is<GetObjectRequest>(r => r.BucketName == bucket && r.Key == key), It.IsAny<CancellationToken>()))
              .ReturnsAsync(getResp);

        var logger = Mock.Of<ILogger<S3Service>>();
        var service = new S3Service(s3Mock.Object, logger);

        var result = await service.GetClaimNotesAsync(bucket, key);
        Assert.AreEqual(content, result);
    }

    [TestMethod]
    public async Task SaveClaimNotesAsync_CallsPutObject()
    {
        var bucket = "b";
        var key = "k";
        var content = "content";

        var s3Mock = new Mock<IAmazonS3>();
        s3Mock.Setup(s => s.PutObjectAsync(It.Is<PutObjectRequest>(r => r.BucketName == bucket && r.Key == key && r.ContentBody == content), It.IsAny<CancellationToken>()))
              .ReturnsAsync(new PutObjectResponse());

        var logger = Mock.Of<ILogger<S3Service>>();
        var service = new S3Service(s3Mock.Object, logger);

        await service.SaveClaimNotesAsync(bucket, key, content);

        s3Mock.Verify(s => s.PutObjectAsync(It.IsAny<PutObjectRequest>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [TestMethod]
    public async Task GetClaimNotesAsync_Throws_OnError()
    {
        var s3Mock = new Mock<IAmazonS3>();
        s3Mock.Setup(s => s.GetObjectAsync(It.IsAny<GetObjectRequest>(), It.IsAny<CancellationToken>()))
              .ThrowsAsync(new AmazonS3Exception("boom"));

        var logger = Mock.Of<ILogger<S3Service>>();
        var service = new S3Service(s3Mock.Object, logger);

        await Assert.ThrowsExceptionAsync<AmazonS3Exception>(() => service.GetClaimNotesAsync("b", "k"));
    }

    [TestMethod]
    public async Task SaveClaimNotesAsync_Throws_OnError()
    {
        var s3Mock = new Mock<IAmazonS3>();
        s3Mock.Setup(s => s.PutObjectAsync(It.IsAny<PutObjectRequest>(), It.IsAny<CancellationToken>()))
              .ThrowsAsync(new AmazonS3Exception("boom"));

        var logger = Mock.Of<ILogger<S3Service>>();
        var service = new S3Service(s3Mock.Object, logger);

        await Assert.ThrowsExceptionAsync<AmazonS3Exception>(() => service.SaveClaimNotesAsync("b", "k", "c"));
    }
}
