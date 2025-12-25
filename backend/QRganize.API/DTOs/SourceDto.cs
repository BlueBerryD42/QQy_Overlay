namespace QRganize.API.DTOs;

public class SourceDto
{
    public int SourceId { get; set; }
    public string? Platform { get; set; }
    public string? SourceUrl { get; set; }
    public string? AuthorHandle { get; set; }
    public string? PostId { get; set; }
    public string? Description { get; set; }
    public DateTime DiscoveredAt { get; set; }
    public bool IsPrimary { get; set; }
}

public class CreateSourceDto
{
    public string? Platform { get; set; }
    public string? SourceUrl { get; set; }
    public string? AuthorHandle { get; set; }
    public string? PostId { get; set; }
    public string? Description { get; set; }
    public bool IsPrimary { get; set; }
}

public class LinkSourceDto
{
    public int SourceId { get; set; }
}

public class UpdateSourceDto
{
    public string? Platform { get; set; }
    public string? SourceUrl { get; set; }
    public string? AuthorHandle { get; set; }
    public string? PostId { get; set; }
    public string? Description { get; set; }
    public bool? IsPrimary { get; set; }
}





