namespace QRganize.API.DTOs;

public class CreatorDto
{
    public int CreatorId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Role { get; set; }
    public string? WebsiteUrl { get; set; }
    public string? SocialLink { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class CreateCreatorDto
{
    public string Name { get; set; } = string.Empty;
    public string? Role { get; set; }
    public string? WebsiteUrl { get; set; }
    public string? SocialLink { get; set; }
}

public class UpdateCreatorDto
{
    public string? Name { get; set; }
    public string? Role { get; set; }
    public string? WebsiteUrl { get; set; }
    public string? SocialLink { get; set; }
}

public class LinkCreatorDto
{
    public int CreatorId { get; set; }
}





