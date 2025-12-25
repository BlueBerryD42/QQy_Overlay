using Microsoft.EntityFrameworkCore.Storage;
using QRganize.Core.Entities;
using QRganize.Core.Interfaces;
using QRganize.Infrastructure.Data;
using QRganize.Infrastructure.Repositories;

namespace QRganize.Infrastructure.UnitOfWork;

/// <summary>
/// Unit of Work implementation for managing repositories and transactions
/// </summary>
public class UnitOfWork : IUnitOfWork
{
    private readonly ApplicationDbContext _context;
    private IDbContextTransaction? _transaction;

    // Lazy initialization of repositories
    private IRepository<Comic>? _comics;
    private IRepository<Page>? _pages;
    private IRepository<OverlayBox>? _overlayBoxes;
    private IRepository<Tag>? _tags;
    private IRepository<TagGroup>? _tagGroups;
    private IRepository<Creator>? _creators;
    private IRepository<Source>? _sources;
    private IRepository<ComicTag>? _comicTags;
    private IRepository<ComicCreator>? _comicCreators;
    private IRepository<ComicSource>? _comicSources;
    private IRepository<TextStyle>? _textStyles;
    private IRepository<Engine>? _engines;
    private IRepository<EngineHistory>? _engineHistories;
    private IRepository<DownloadSource>? _downloadSources;

    public UnitOfWork(ApplicationDbContext context)
    {
        _context = context;
    }

    public IRepository<Comic> Comics => _comics ??= new Repository<Comic>(_context);
    public IRepository<Page> Pages => _pages ??= new Repository<Page>(_context);
    public IRepository<OverlayBox> OverlayBoxes => _overlayBoxes ??= new Repository<OverlayBox>(_context);
    public IRepository<Tag> Tags => _tags ??= new Repository<Tag>(_context);
    public IRepository<TagGroup> TagGroups => _tagGroups ??= new Repository<TagGroup>(_context);
    public IRepository<Creator> Creators => _creators ??= new Repository<Creator>(_context);
    public IRepository<Source> Sources => _sources ??= new Repository<Source>(_context);
    public IRepository<ComicTag> ComicTags => _comicTags ??= new Repository<ComicTag>(_context);
    public IRepository<ComicCreator> ComicCreators => _comicCreators ??= new Repository<ComicCreator>(_context);
    public IRepository<ComicSource> ComicSources => _comicSources ??= new Repository<ComicSource>(_context);
    public IRepository<TextStyle> TextStyles => _textStyles ??= new Repository<TextStyle>(_context);
    public IRepository<Engine> Engines => _engines ??= new Repository<Engine>(_context);
    public IRepository<EngineHistory> EngineHistories => _engineHistories ??= new Repository<EngineHistory>(_context);
    public IRepository<DownloadSource> DownloadSources => _downloadSources ??= new Repository<DownloadSource>(_context);

    public async Task<int> SaveChangesAsync()
    {
        return await _context.SaveChangesAsync();
    }

    public async Task BeginTransactionAsync()
    {
        _transaction = await _context.Database.BeginTransactionAsync();
    }

    public async Task CommitTransactionAsync()
    {
        if (_transaction != null)
        {
            await _transaction.CommitAsync();
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public async Task RollbackTransactionAsync()
    {
        if (_transaction != null)
        {
            await _transaction.RollbackAsync();
            await _transaction.DisposeAsync();
            _transaction = null;
        }
    }

    public void Dispose()
    {
        _transaction?.Dispose();
        // Don't dispose context here - it's managed by the DI container/service scope
    }
}




