namespace QRganize.Core.Entities;

public class Page
{
    public int PageId { get; set; }
    public int ComicId { get; set; }
    public int PageNumber { get; set; }
    public string StoragePath { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public string? FileExtension { get; set; }
    public int? FileSizeBytes { get; set; }
    public int? Width { get; set; }
    public int? Height { get; set; }
    public int? Dpi { get; set; }
    public string? ColorProfile { get; set; }
    public string? ImageHash { get; set; }
    public string? ThumbnailPath { get; set; }
    public DateTime CreatedAt { get; set; }

    // Navigation properties
    public Comic Comic { get; set; } = null!;
    public ICollection<OverlayBox> OverlayBoxes { get; set; } = new List<OverlayBox>();
}








