namespace QRganize.Core.Entities;

public class Comic
{
    public int ComicId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? AlternativeTitle { get; set; }
    public string? Description { get; set; }
    public string ManagedPath { get; set; } = string.Empty;
    public string? CoverImagePath { get; set; }
    public int? CoverPageId { get; set; }
    public string Status { get; set; } = "active";
    public int? Rating { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public Page? CoverPage { get; set; }
    public ICollection<Page> Pages { get; set; } = new List<Page>();
    public ICollection<ComicTag> ComicTags { get; set; } = new List<ComicTag>();
    public ICollection<ComicCreator> ComicCreators { get; set; } = new List<ComicCreator>();
    public ICollection<ComicSource> ComicSources { get; set; } = new List<ComicSource>();
}








