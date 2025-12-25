namespace QRganize.API.DTOs;

public class ComicDto
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
}

public class CreateComicDto
{
    public string Title { get; set; } = string.Empty;
    public string? AlternativeTitle { get; set; }
    public string? Description { get; set; }
    public string ManagedPath { get; set; } = string.Empty;
    public string? CoverImagePath { get; set; }
    public int? CoverPageId { get; set; }
    public string Status { get; set; } = "active";
    public int? Rating { get; set; }
}

public class UpdateComicDto
{
    public string? Title { get; set; }
    public string? AlternativeTitle { get; set; }
    public string? Description { get; set; }
    public string? ManagedPath { get; set; }
    public string? CoverImagePath { get; set; }
    public int? CoverPageId { get; set; }
    public string? Status { get; set; }
    public int? Rating { get; set; }
}








