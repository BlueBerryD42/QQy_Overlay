namespace QRganize.Core.Entities;

public class Engine
{
    public int EngineId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Type { get; set; } = string.Empty;
    public string? ApiEndpoint { get; set; }
    public string? ApiKey { get; set; }
    public string? Configuration { get; set; }
    public bool IsActive { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    // Navigation properties
    public ICollection<EngineHistory> EngineHistories { get; set; } = new List<EngineHistory>();
}








