using System;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using ClaimStatusApi.Models;
using ClaimStatusApi.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Moq;

namespace ClaimStatusApi.Tests;

[TestClass]
public class BedrockServiceTests
{
    
    private BedrockService CreateService()
    {
        var config = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>
        {
            ["AWS:Bedrock:ModelId"] = "test-model"
        }).Build();
        var logger = Mock.Of<ILogger<BedrockService>>();
        var fakeRuntime = Mock.Of<Amazon.BedrockRuntime.IAmazonBedrockRuntime>();
        return new BedrockService(fakeRuntime, logger, config);
    }

    [TestMethod]
    public void ExtractJsonPayload_ReturnsInnerJson_FromFencedBlock()
    {
        var text = "Some text\n```json\n{\"a\":1}\n```\nTrailing";
        var method = typeof(BedrockService).GetMethod("ExtractJsonPayload", BindingFlags.Static | BindingFlags.NonPublic);
        Assert.IsNotNull(method);
        var result = method!.Invoke(null, new object[] { text }) as string;
        Assert.IsNotNull(result);
        Assert.IsTrue(result.Trim().StartsWith("{") && result.Trim().EndsWith("}"));
        Assert.IsTrue(result.Contains("\"a\":1"));
    }

    [TestMethod]
    public void ExtractJsonPayload_ExtractsBetweenBraces_WhenNoFence()
    {
        var text = "prefix { \"x\": 2 } suffix";
        var method = typeof(BedrockService).GetMethod("ExtractJsonPayload", BindingFlags.Static | BindingFlags.NonPublic);
        Assert.IsNotNull(method);
        var result = method!.Invoke(null, new object[] { text }) as string;
        Assert.IsNotNull(result);
        Assert.IsTrue(result.Contains("\"x\": 2"));
    }

    [TestMethod]
    public void ExtractJsonPayload_FencedAtStart_StripsLanguageTag()
    {
        var text = "```json\n{\"k\":\"v\"}\n```";
        var method = typeof(BedrockService).GetMethod("ExtractJsonPayload", BindingFlags.Static | BindingFlags.NonPublic);
        Assert.IsNotNull(method);
        var result = method!.Invoke(null, new object[] { text }) as string;
        Assert.IsNotNull(result);
        Assert.IsTrue(result.Trim().StartsWith("{") && result.Trim().EndsWith("}"));
        Assert.IsTrue(result.Contains("\"k\":\"v\""));
    }

    [TestMethod]
    public void ExtractJsonPayload_FencedAtStart_NoLanguage()
    {
        var text = "```\n{\"a\":1}\n```";
        var method = typeof(BedrockService).GetMethod("ExtractJsonPayload", BindingFlags.Static | BindingFlags.NonPublic);
        Assert.IsNotNull(method);
        var result = method!.Invoke(null, new object[] { text }) as string;
        Assert.IsNotNull(result);
        Assert.IsTrue(result.Trim().StartsWith("{") && result.Trim().EndsWith("}"));
        Assert.IsTrue(result.Contains("\"a\":1"));
    }

    [TestMethod]
    public void ExtractJsonPayload_FencedLanguage_UppercaseJSON()
    {
        var text = "```JSON\n{\"u\":true}\n```";
        var method = typeof(BedrockService).GetMethod("ExtractJsonPayload", BindingFlags.Static | BindingFlags.NonPublic);
        Assert.IsNotNull(method);
        var result = method!.Invoke(null, new object[] { text }) as string;
        Assert.IsNotNull(result);
        Assert.IsTrue(result.Trim().StartsWith("{") && result.Trim().EndsWith("}"));
        Assert.IsTrue(result.Contains("\"u\":true"));
    }

    [TestMethod]
    public void ExtractJsonPayload_ReturnsTrimmed_WhenNoFenceOrBraces()
    {
        var text = "  just plain text  ";
        var method = typeof(BedrockService).GetMethod("ExtractJsonPayload", BindingFlags.Static | BindingFlags.NonPublic);
        Assert.IsNotNull(method);
        var result = method!.Invoke(null, new object[] { text }) as string;
        Assert.IsNotNull(result);
        Assert.AreEqual("just plain text", result);
    }

    [TestMethod]
    public void ParseSummaryResponse_ParsesExpectedJson()
    {
        var service = CreateService();

        var json = "{\"overall_summary\":\"o\",\"customer_facing_summary\":\"c\",\"adjuster_focused_summary\":\"a\",\"recommended_next_step\":\"r\"}";
        var method = typeof(BedrockService).GetMethod("ParseSummaryResponse", BindingFlags.Instance | BindingFlags.NonPublic);
        Assert.IsNotNull(method);

        var summary = method!.Invoke(service, new object[] { json, "CID" }) as ClaimSummary;
        Assert.IsNotNull(summary);
        Assert.AreEqual("CID", summary!.ClaimId);
        Assert.AreEqual("o", summary.OverallSummary);
        Assert.AreEqual("c", summary.CustomerFacingSummary);
        Assert.AreEqual("a", summary.AdjusterFocusedSummary);
        Assert.AreEqual("r", summary.RecommendedNextStep);
    }

    [TestMethod]
    public async Task GenerateSummary_UsesInferenceProfileId_AndParses()
    {
        var cfg = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>
        {
            ["AWS:Bedrock:InferenceProfileId"] = "ip-123"
        }).Build();

        var logger = Mock.Of<ILogger<BedrockService>>();
        var runtimeMock = new Mock<Amazon.BedrockRuntime.IAmazonBedrockRuntime>();
        Amazon.BedrockRuntime.Model.ConverseRequest? captured = null;
        runtimeMock.Setup(r => r.ConverseAsync(It.IsAny<Amazon.BedrockRuntime.Model.ConverseRequest>(), It.IsAny<CancellationToken>()))
            .Callback<Amazon.BedrockRuntime.Model.ConverseRequest, CancellationToken>((req, ct) => captured = req)
            .ReturnsAsync(new Amazon.BedrockRuntime.Model.ConverseResponse
            {
                Output = new Amazon.BedrockRuntime.Model.ConverseOutput
                {
                    Message = new Amazon.BedrockRuntime.Model.Message
                    {
                        Content = new System.Collections.Generic.List<Amazon.BedrockRuntime.Model.ContentBlock>
                        {
                            new Amazon.BedrockRuntime.Model.ContentBlock { Text = "{\"overall_summary\":\"o\",\"customer_facing_summary\":\"c\",\"adjuster_focused_summary\":\"a\",\"recommended_next_step\":\"r\"}" }
                        }
                    }
                }
            });

        var service = new BedrockService(runtimeMock.Object, logger, cfg);
        var summary = await service.GenerateSummaryAsync("CID", "notes");

        Assert.IsNotNull(captured);
        Assert.AreEqual("ip-123", captured!.ModelId);
        Assert.AreEqual("ip-123", summary.Model);
        Assert.AreEqual("CID", summary.ClaimId);
    }

    [TestMethod]
    public async Task GenerateSummary_UsesInferenceProfileArn_AndParses()
    {
        var cfg = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>
        {
            ["AWS:Bedrock:InferenceProfileArn"] = "arn:aws:bedrock:us-east-1:123:inference-profile/abc"
        }).Build();

        var logger = Mock.Of<ILogger<BedrockService>>();
        var runtimeMock = new Mock<Amazon.BedrockRuntime.IAmazonBedrockRuntime>();
        Amazon.BedrockRuntime.Model.ConverseRequest? captured = null;
        runtimeMock.Setup(r => r.ConverseAsync(It.IsAny<Amazon.BedrockRuntime.Model.ConverseRequest>(), It.IsAny<CancellationToken>()))
            .Callback<Amazon.BedrockRuntime.Model.ConverseRequest, CancellationToken>((req, ct) => captured = req)
            .ReturnsAsync(new Amazon.BedrockRuntime.Model.ConverseResponse
            {
                Output = new Amazon.BedrockRuntime.Model.ConverseOutput
                {
                    Message = new Amazon.BedrockRuntime.Model.Message
                    {
                        Content = new System.Collections.Generic.List<Amazon.BedrockRuntime.Model.ContentBlock>
                        {
                            new Amazon.BedrockRuntime.Model.ContentBlock { Text = "{\"overall_summary\":\"o\",\"customer_facing_summary\":\"c\",\"adjuster_focused_summary\":\"a\",\"recommended_next_step\":\"r\"}" }
                        }
                    }
                }
            });

        var service = new BedrockService(runtimeMock.Object, logger, cfg);
        var summary = await service.GenerateSummaryAsync("CID", "notes");

        Assert.IsNotNull(captured);
        Assert.AreEqual("arn:aws:bedrock:us-east-1:123:inference-profile/abc", captured!.ModelId);
        Assert.AreEqual("arn:aws:bedrock:us-east-1:123:inference-profile/abc", summary.Model);
    }

    [TestMethod]
    public async Task GenerateSummary_UsesDefaultModel_WhenNoProfiles()
    {
        var cfg = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>
        {
            ["AWS:Bedrock:ModelId"] = "model-xyz"
        }).Build();

        var logger = Mock.Of<ILogger<BedrockService>>();
        var runtimeMock = new Mock<Amazon.BedrockRuntime.IAmazonBedrockRuntime>();
        Amazon.BedrockRuntime.Model.ConverseRequest? captured = null;
        runtimeMock.Setup(r => r.ConverseAsync(It.IsAny<Amazon.BedrockRuntime.Model.ConverseRequest>(), It.IsAny<CancellationToken>()))
            .Callback<Amazon.BedrockRuntime.Model.ConverseRequest, CancellationToken>((req, ct) => captured = req)
            .ReturnsAsync(new Amazon.BedrockRuntime.Model.ConverseResponse
            {
                Output = new Amazon.BedrockRuntime.Model.ConverseOutput
                {
                    Message = new Amazon.BedrockRuntime.Model.Message
                    {
                        Content = new System.Collections.Generic.List<Amazon.BedrockRuntime.Model.ContentBlock>
                        {
                            new Amazon.BedrockRuntime.Model.ContentBlock { Text = "{\"overall_summary\":\"o\",\"customer_facing_summary\":\"c\",\"adjuster_focused_summary\":\"a\",\"recommended_next_step\":\"r\"}" }
                        }
                    }
                }
            });

        var service = new BedrockService(runtimeMock.Object, logger, cfg);
        var summary = await service.GenerateSummaryAsync("CID", "notes");

        Assert.IsNotNull(captured);
        Assert.AreEqual("model-xyz", captured!.ModelId);
        Assert.AreEqual("model-xyz", summary.Model);
    }

    [TestMethod]
    public async Task GenerateSummary_Throws_OnEmptyResponse()
    {
        var cfg = new ConfigurationBuilder().AddInMemoryCollection().Build();
        var logger = Mock.Of<ILogger<BedrockService>>();
        var runtimeMock = new Mock<Amazon.BedrockRuntime.IAmazonBedrockRuntime>();
        runtimeMock.Setup(r => r.ConverseAsync(It.IsAny<Amazon.BedrockRuntime.Model.ConverseRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Amazon.BedrockRuntime.Model.ConverseResponse
            {
                Output = new Amazon.BedrockRuntime.Model.ConverseOutput
                {
                    Message = new Amazon.BedrockRuntime.Model.Message
                    {
                        Content = new System.Collections.Generic.List<Amazon.BedrockRuntime.Model.ContentBlock>()
                    }
                }
            });

        var service = new BedrockService(runtimeMock.Object, logger, cfg);
        await Assert.ThrowsExceptionAsync<System.Collections.Generic.KeyNotFoundException>(() => service.GenerateSummaryAsync("CID", "notes"));
    }

    [TestMethod]
    public async Task GenerateSummary_Throws_WhenNoMessage()
    {
        var cfg = new ConfigurationBuilder().AddInMemoryCollection().Build();
        var logger = Mock.Of<ILogger<BedrockService>>();
        var runtimeMock = new Mock<Amazon.BedrockRuntime.IAmazonBedrockRuntime>();
        // Simulate response with no Output/Message to hit the fallback branch
        runtimeMock.Setup(r => r.ConverseAsync(It.IsAny<Amazon.BedrockRuntime.Model.ConverseRequest>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new Amazon.BedrockRuntime.Model.ConverseResponse
            {
                Output = null
            });

        var service = new BedrockService(runtimeMock.Object, logger, cfg);
        await Assert.ThrowsExceptionAsync<System.Collections.Generic.KeyNotFoundException>(() => service.GenerateSummaryAsync("CID", "notes"));
    }
}
