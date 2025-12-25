using Microsoft.Extensions.DependencyInjection;
using QRganize.Core.Entities;
using QRganize.Core.Interfaces;
using QRganize.Infrastructure.Data;
using UnitOfWorkImpl = QRganize.Infrastructure.UnitOfWork.UnitOfWork;

namespace QRganize.Infrastructure.Factories;

/// <summary>
/// Factory for creating UnitOfWork instances
/// </summary>
public class UnitOfWorkFactory : IUnitOfWorkFactory
{
    private readonly IServiceScopeFactory _serviceScopeFactory;

    public UnitOfWorkFactory(IServiceScopeFactory serviceScopeFactory)
    {
        _serviceScopeFactory = serviceScopeFactory;
    }

    public IUnitOfWork Create()
    {
        var scope = _serviceScopeFactory.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        var unitOfWork = new UnitOfWorkImpl(context);
        return new ScopedUnitOfWork(unitOfWork, scope);
    }

    /// <summary>
    /// Wrapper to manage service scope lifecycle with UnitOfWork
    /// </summary>
    private class ScopedUnitOfWork : IUnitOfWork
    {
        private readonly IUnitOfWork _unitOfWork;
        private readonly IServiceScope _scope;

        public ScopedUnitOfWork(IUnitOfWork unitOfWork, IServiceScope scope)
        {
            _unitOfWork = unitOfWork;
            _scope = scope;
        }

        public IRepository<Comic> Comics => _unitOfWork.Comics;
        public IRepository<Page> Pages => _unitOfWork.Pages;
        public IRepository<OverlayBox> OverlayBoxes => _unitOfWork.OverlayBoxes;
        public IRepository<Tag> Tags => _unitOfWork.Tags;
        public IRepository<TagGroup> TagGroups => _unitOfWork.TagGroups;
        public IRepository<Creator> Creators => _unitOfWork.Creators;
        public IRepository<Source> Sources => _unitOfWork.Sources;
        public IRepository<ComicTag> ComicTags => _unitOfWork.ComicTags;
        public IRepository<ComicCreator> ComicCreators => _unitOfWork.ComicCreators;
        public IRepository<ComicSource> ComicSources => _unitOfWork.ComicSources;
        public IRepository<TextStyle> TextStyles => _unitOfWork.TextStyles;
        public IRepository<Engine> Engines => _unitOfWork.Engines;
        public IRepository<EngineHistory> EngineHistories => _unitOfWork.EngineHistories;
        public IRepository<DownloadSource> DownloadSources => _unitOfWork.DownloadSources;

        public Task<int> SaveChangesAsync() => _unitOfWork.SaveChangesAsync();
        public Task BeginTransactionAsync() => _unitOfWork.BeginTransactionAsync();
        public Task CommitTransactionAsync() => _unitOfWork.CommitTransactionAsync();
        public Task RollbackTransactionAsync() => _unitOfWork.RollbackTransactionAsync();

        public void Dispose()
        {
            _unitOfWork?.Dispose();
            _scope?.Dispose();
        }
    }
}

