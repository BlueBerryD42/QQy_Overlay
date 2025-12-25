namespace QRganize.Core.Entities;

public class TextStyle
{
    public int TextStyleId { get; set; }
    public string FontFamily { get; set; } = string.Empty;
    public double FontSize { get; set; }
    public string FontWeight { get; set; } = "normal";
    public string FontStyle { get; set; } = "normal";
    public string? Color { get; set; }
    public string? BackgroundColor { get; set; }
    public double? LetterSpacing { get; set; }
    public double? LineHeight { get; set; }
    public string? TextAlign { get; set; }
    public DateTime CreatedAt { get; set; }
}








