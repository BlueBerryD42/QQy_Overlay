namespace QRganize.Core.Interfaces;

/// <summary>
/// Unit of Work interface for managing repositories and transactions
/// </summary>
public interface IUnitOfWork : IDisposable
{
    // Repository properties for each entity
    IRepository<Entities.Comic> Comics { get; }
    IRepository<Entities.Page> Pages { get; }
    IRepository<Entities.OverlayBox> OverlayBoxes { get; }
    IRepository<Entities.Tag> Tags { get; }
    IRepository<Entities.TagGroup> TagGroups { get; }
    IRepository<Entities.Creator> Creators { get; }
    IRepository<Entities.Source> Sources { get; }
    IRepository<Entities.ComicTag> ComicTags { get; }
    IRepository<Entities.ComicCreator> ComicCreators { get; }
    IRepository<Entities.ComicSource> ComicSources { get; }
    IRepository<Entities.TextStyle> TextStyles { get; }
    IRepository<Entities.Engine> Engines { get; }
    IRepository<Entities.EngineHistory> EngineHistories { get; }
    IRepository<Entities.DownloadSource> DownloadSources { get; }

    /// <summary>
    /// Save all changes to database
    /// </summary>
    Task<int> SaveChangesAsync();

    /// <summary>
    /// Begin a database transaction
    /// </summary>
    Task BeginTransactionAsync();

    /// <summary>
    /// Commit the current transaction
    /// </summary>
    Task CommitTransactionAsync();

    /// <summary>
    /// Rollback the current transaction
    /// </summary>
    Task RollbackTransactionAsync();
}








