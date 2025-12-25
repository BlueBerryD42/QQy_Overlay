namespace QRganize.Core.Entities;

public class EngineHistory
{
    public int HistoryId { get; set; }
    public int EngineId { get; set; }
    public int? OverlayBoxId { get; set; }
    public string? OriginalText { get; set; }
    public string? TranslatedText { get; set; }
    public string? Status { get; set; }
    public string? ErrorMessage { get; set; }
    public DateTime ProcessedAt { get; set; }

    // Navigation properties
    public Engine Engine { get; set; } = null!;
    public OverlayBox? OverlayBox { get; set; }
}








