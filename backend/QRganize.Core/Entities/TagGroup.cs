namespace QRganize.Core.Entities;

public class TagGroup
{
    public int GroupId { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }

    // Navigation properties
    public ICollection<Tag> Tags { get; set; } = new List<Tag>();
}








