namespace QRganize.Core.Entities;

public class ComicCreator
{
    public int ComicId { get; set; }
    public int CreatorId { get; set; }

    // Navigation properties
    public Comic Comic { get; set; } = null!;
    public Creator Creator { get; set; } = null!;
}








