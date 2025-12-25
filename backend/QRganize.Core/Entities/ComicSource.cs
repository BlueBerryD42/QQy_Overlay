namespace QRganize.Core.Entities;

public class ComicSource
{
    public int ComicId { get; set; }
    public int SourceId { get; set; }

    // Navigation properties
    public Comic Comic { get; set; } = null!;
    public Source Source { get; set; } = null!;
}








