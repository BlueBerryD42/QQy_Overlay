namespace QRganize.API.DTOs;

public class TagDto
{
    public int TagId { get; set; }
    public int? GroupId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsSensitive { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class CreateTagDto
{
    public int? GroupId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsSensitive { get; set; }
}

public class TagGroupDto
{
    public int GroupId { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}

public class CreateTagGroupDto
{
    public string Name { get; set; } = string.Empty;
}

public class LinkTagDto
{
    public int TagId { get; set; }
}





