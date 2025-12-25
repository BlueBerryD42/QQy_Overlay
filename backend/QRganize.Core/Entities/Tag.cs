namespace QRganize.Core.Entities;

public class Tag
{
    public int TagId { get; set; }
    public int? GroupId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsSensitive { get; set; }
    public DateTime CreatedAt { get; set; }

    // Navigation properties
    public TagGroup? TagGroup { get; set; }
    public ICollection<ComicTag> ComicTags { get; set; } = new List<ComicTag>();
}








