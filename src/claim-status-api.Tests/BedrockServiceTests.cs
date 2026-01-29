using System;
using System.Reflection;
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
    {        var config = new ConfigurationBuilder().AddInMemoryCollection(new System.Collections.Generic.Dictionary<string, string?>        {            ["AWS:Bedrock:ModelId"] = "test-model"        }).Build();        var logger = Mock.Of<ILogger<BedrockService>>();        var fakeRuntime = Mock.Of<Amazon.BedrockRuntime.IAmazonBedrockRuntime>();        return new BedrockService(fakeRuntime, logger, config);    }    [TestMethod]    public void ExtractJsonPayload_ReturnsInnerJson_FromFencedBlock()    {        var text = "Some text\n```json\n{\"a\":1}\n```\nTrailing";        var method = typeof(BedrockService).GetMethod("ExtractJsonPayload", BindingFlags.Static | BindingFlags.NonPublic);        Assert.IsNotNull(method);        var result = method!.Invoke(null, new object[] { text }) as string;        Assert.IsNotNull(result);        Assert.IsTrue(result.Trim().StartsWith("{") && result.Trim().EndsWith("}"));        Assert.IsTrue(result.Contains("\"a\":1"));    }    [TestMethod]    public void ExtractJsonPayload_ExtractsBetweenBraces_WhenNoFence()    {        var text = "prefix { \"x\": 2 } suffix";        var method = typeof(BedrockService).GetMethod("ExtractJsonPayload", BindingFlags.Static | BindingFlags.NonPublic);        Assert.IsNotNull(method);        var result = method!.Invoke(null, new object[] { text }) as string;        Assert.IsNotNull(result);        Assert.IsTrue(result.Contains("\"x\": 2"));    }    [TestMethod]    public void ParseSummaryResponse_ParsesExpectedJson()    {        var service = CreateService();        var json = "{\"overall_summary\":\"o\",\"customer_facing_summary\":\"c\",\"adjuster_focused_summary\":\"a\",\"recommended_next_step\":\"r\"}";        var method = typeof(BedrockService).GetMethod("ParseSummaryResponse", BindingFlags.Instance | BindingFlags.NonPublic);        Assert.IsNotNull(method);        var summary = method!.Invoke(service, new object[] { json, "CID" }) as ClaimSummary;        Assert.IsNotNull(summary);        Assert.AreEqual("CID", summary!.ClaimId);        Assert.AreEqual("o", summary.OverallSummary);        Assert.AreEqual("c", summary.CustomerFacingSummary);        Assert.AreEqual("a", summary.AdjusterFocusedSummary);        Assert.AreEqual("r", summary.RecommendedNextStep);    }}
