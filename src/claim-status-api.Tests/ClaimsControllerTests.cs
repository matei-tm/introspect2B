using System.Collections.Generic;
using System.Threading.Tasks;
using ClaimStatusApi.Controllers;
using ClaimStatusApi.Models;
using ClaimStatusApi.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;

namespace ClaimStatusApi.Tests;

[TestClass]
public class ClaimsControllerTests
{
    private Mock<IDynamoDbService> _dynamoMock = null!;
    private Mock<IS3Service> _s3Mock = null!;
    private Mock<IBedrockService> _bedrockMock = null!;
    private Mock<ILogger<ClaimsController>> _loggerMock = null!;
    private IConfiguration _config = null!;

    [TestInitialize]
    public void Init()
    {
        _dynamoMock = new Mock<IDynamoDbService>();
        _s3Mock = new Mock<IS3Service>();
        _bedrockMock = new Mock<IBedrockService>();
        _loggerMock = new Mock<ILogger<ClaimsController>>();

        var inMemory = new Dictionary<string, string?>
        {
            ["AWS:S3:BucketName"] = "claim-notes"
        };
        _config = new ConfigurationBuilder().AddInMemoryCollection(inMemory!).Build();
    }

    [TestMethod]
    public async Task GetClaim_ReturnsOk_WhenFound()
    {
        var id = "CLAIM-001";
        var claim = new ClaimStatus { Id = id, NotesKey = "k" };
        _dynamoMock.Setup(d => d.GetClaimStatusAsync(id)).ReturnsAsync(claim);

        var controller = new ClaimsController(_dynamoMock.Object, _s3Mock.Object, _bedrockMock.Object, _loggerMock.Object, _config);
        var result = await controller.GetClaim(id);

        Assert.IsInstanceOfType(result.Result, typeof(OkObjectResult));
        var ok = result.Result as OkObjectResult;
        Assert.IsNotNull(ok);
        Assert.AreEqual(claim, ok!.Value);
    }

    [TestMethod]
    public async Task GetClaim_ReturnsNotFound_WhenMissing()
    {
        var id = "MISSING";
        _dynamoMock.Setup(d => d.GetClaimStatusAsync(id)).ReturnsAsync((ClaimStatus?)null);

        var controller = new ClaimsController(_dynamoMock.Object, _s3Mock.Object, _bedrockMock.Object, _loggerMock.Object, _config);
        var result = await controller.GetClaim(id);

        Assert.IsInstanceOfType(result.Result, typeof(NotFoundObjectResult));
    }

    [TestMethod]
    public async Task GetClaim_Returns500_OnException()
    {
        var id = "ERR";
        _dynamoMock.Setup(d => d.GetClaimStatusAsync(It.IsAny<string>())).ThrowsAsync(new System.InvalidOperationException("boom"));

        var controller = new ClaimsController(_dynamoMock.Object, _s3Mock.Object, _bedrockMock.Object, _loggerMock.Object, _config);
        var result = await controller.GetClaim(id);

        Assert.IsInstanceOfType(result.Result, typeof(ObjectResult));
        var obj = result.Result as ObjectResult;
        Assert.AreEqual(500, obj!.StatusCode);
    }

    [TestMethod]
    public async Task SummarizeClaim_ReturnsNotFound_WhenClaimMissing()
    {
        var id = "M1";
        _dynamoMock.Setup(d => d.GetClaimStatusAsync(id)).ReturnsAsync((ClaimStatus?)null);

        var controller = new ClaimsController(_dynamoMock.Object, _s3Mock.Object, _bedrockMock.Object, _loggerMock.Object, _config);
        var result = await controller.SummarizeClaim(id, null);

        Assert.IsInstanceOfType(result.Result, typeof(NotFoundObjectResult));
    }

    [TestMethod]
    public async Task SummarizeClaim_UsesNotesOverride_WhenProvided()
    {
        var id = "C1";
        var claim = new ClaimStatus { Id = id, NotesKey = "k" };
        var request = new SummarizeRequest { NotesOverride = "override notes" };
        var expectedSummary = new ClaimSummary { ClaimId = id, OverallSummary = "x" };

        _dynamoMock.Setup(d => d.GetClaimStatusAsync(id)).ReturnsAsync(claim);
        _bedrockMock.Setup(b => b.GenerateSummaryAsync(id, request.NotesOverride!)).ReturnsAsync(expectedSummary);

        var controller = new ClaimsController(_dynamoMock.Object, _s3Mock.Object, _bedrockMock.Object, _loggerMock.Object, _config);
        var result = await controller.SummarizeClaim(id, request);

        Assert.IsInstanceOfType(result.Result, typeof(OkObjectResult));
        var ok = result.Result as OkObjectResult;
        Assert.IsNotNull(ok);
        Assert.AreEqual(expectedSummary, ok!.Value);
    }

    [TestMethod]
    public async Task SummarizeClaim_GetsNotesFromS3_WhenNoOverride()
    {
        var id = "C2";
        var claim = new ClaimStatus { Id = id, NotesKey = "notes/key.txt" };
        var s3Content = "notes content";
        var expectedSummary = new ClaimSummary { ClaimId = id, OverallSummary = "summary" };

        _dynamoMock.Setup(d => d.GetClaimStatusAsync(id)).ReturnsAsync(claim);
        _s3Mock.Setup(s => s.GetClaimNotesAsync("claim-notes", claim.NotesKey)).ReturnsAsync(s3Content);
        _bedrockMock.Setup(b => b.GenerateSummaryAsync(id, s3Content)).ReturnsAsync(expectedSummary);

        var controller = new ClaimsController(_dynamoMock.Object, _s3Mock.Object, _bedrockMock.Object, _loggerMock.Object, _config);
        var result = await controller.SummarizeClaim(id, null);

        Assert.IsInstanceOfType(result.Result, typeof(OkObjectResult));
        _s3Mock.Verify(s => s.GetClaimNotesAsync("claim-notes", claim.NotesKey), Times.Once);
    }

    [TestMethod]
    public async Task SummarizeClaim_EmptyOverride_FallsBackToS3()
    {
        var id = "C4";
        var claim = new ClaimStatus { Id = id, NotesKey = "notes/key.txt" };
        var s3Content = "fallback notes";
        var request = new SummarizeRequest { NotesOverride = string.Empty };
        var expectedSummary = new ClaimSummary { ClaimId = id, OverallSummary = "y" };

        _dynamoMock.Setup(d => d.GetClaimStatusAsync(id)).ReturnsAsync(claim);
        _s3Mock.Setup(s => s.GetClaimNotesAsync("claim-notes", claim.NotesKey)).ReturnsAsync(s3Content);
        _bedrockMock.Setup(b => b.GenerateSummaryAsync(id, s3Content)).ReturnsAsync(expectedSummary);

        var controller = new ClaimsController(_dynamoMock.Object, _s3Mock.Object, _bedrockMock.Object, _loggerMock.Object, _config);
        var result = await controller.SummarizeClaim(id, request);

        Assert.IsInstanceOfType(result.Result, typeof(OkObjectResult));
        _s3Mock.Verify(s => s.GetClaimNotesAsync("claim-notes", claim.NotesKey), Times.Once);
    }

    [TestMethod]
    public async Task SummarizeClaim_Returns500_OnBedrockError()
    {
        var id = "C3";
        var claim = new ClaimStatus { Id = id, NotesKey = "notes/key.txt" };

        _dynamoMock.Setup(d => d.GetClaimStatusAsync(id)).ReturnsAsync(claim);
        _s3Mock.Setup(s => s.GetClaimNotesAsync(It.IsAny<string>(), It.IsAny<string>())).ReturnsAsync("x");
        _bedrockMock.Setup(b => b.GenerateSummaryAsync(It.IsAny<string>(), It.IsAny<string>())).ThrowsAsync(new System.Exception("bedrock"));

        var controller = new ClaimsController(_dynamoMock.Object, _s3Mock.Object, _bedrockMock.Object, _loggerMock.Object, _config);
        var result = await controller.SummarizeClaim(id, null);

        Assert.IsInstanceOfType(result.Result, typeof(ObjectResult));
        var obj = result.Result as ObjectResult;
        Assert.AreEqual(500, obj!.StatusCode);
    }
}
