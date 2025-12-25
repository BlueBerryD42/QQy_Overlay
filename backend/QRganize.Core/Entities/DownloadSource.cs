namespace QRganize.Core.Entities;

public class DownloadSource
{
    public int DownloadSourceId { get; set; }
    public string? Platform { get; set; }
    public string? SourceUrl { get; set; }
    public string? AuthorHandle { get; set; }
    public string? PostId { get; set; }
    public string? Description { get; set; }
    public DateTime DiscoveredAt { get; set; }
    public bool IsPrimary { get; set; }
}








