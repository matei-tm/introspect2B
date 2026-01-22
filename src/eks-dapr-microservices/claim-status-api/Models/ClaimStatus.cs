namespace ClaimStatusApi.Models;

public class ClaimStatus
{
    public string Id { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public string ClaimType { get; set; } = string.Empty;
    public DateTime SubmissionDate { get; set; }
    public string ClaimantName { get; set; } = string.Empty;
    public decimal Amount { get; set; }
    public string NotesKey { get; set; } = string.Empty; // S3 key to claim notes
}
