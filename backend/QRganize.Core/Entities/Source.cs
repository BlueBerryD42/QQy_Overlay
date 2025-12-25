namespace QRganize.Core.Entities;

public class Source
{
    public int SourceId { get; set; }
    public string? Platform { get; set; }
    public string? SourceUrl { get; set; }
    public string? AuthorHandle { get; set; }
    public string? PostId { get; set; }
    public string? Description { get; set; }
    public DateTime DiscoveredAt { get; set; }
    public bool IsPrimary { get; set; }

    // Navigation properties
    public ICollection<ComicSource> ComicSources { get; set; } = new List<ComicSource>();
}








