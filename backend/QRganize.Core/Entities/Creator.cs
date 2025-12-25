namespace QRganize.Core.Entities;

public class Creator
{
    public int CreatorId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Role { get; set; }
    public string? WebsiteUrl { get; set; }
    public string? SocialLink { get; set; }
    public DateTime CreatedAt { get; set; }

    // Navigation properties
    public ICollection<ComicCreator> ComicCreators { get; set; } = new List<ComicCreator>();
}








