namespace QRganize.Core.Entities;

public class OverlayBox
{
    public int OverlayId { get; set; }
    public int PageId { get; set; }
    public double X { get; set; }
    public double Y { get; set; }
    public double Width { get; set; }
    public double Height { get; set; }
    public double Rotation { get; set; }
    public int ZIndex { get; set; }
    public string? OriginalText { get; set; }
    public string? TranslatedText { get; set; }
    public bool IsVerified { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public Page Page { get; set; } = null!;
}








