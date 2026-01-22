namespace ClaimStatusApi.Models;

public class ClaimSummary
{
    public string ClaimId { get; set; } = string.Empty;
    public string OverallSummary { get; set; } = string.Empty;
    public string CustomerFacingSummary { get; set; } = string.Empty;
    public string AdjusterFocusedSummary { get; set; } = string.Empty;
    public string RecommendedNextStep { get; set; } = string.Empty;
    public DateTime GeneratedAt { get; set; }
    public string Model { get; set; } = "anthropic.claude-3-haiku-20240307-v1:0";
}
