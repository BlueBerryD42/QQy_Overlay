namespace QRganize.Core.Entities;

public class ComicTag
{
    public int ComicId { get; set; }
    public int TagId { get; set; }

    // Navigation properties
    public Comic Comic { get; set; } = null!;
    public Tag Tag { get; set; } = null!;
}








