using System.Linq.Expressions;

namespace QRganize.Core.Interfaces;

/// <summary>
/// Generic repository interface with common CRUD operations
/// </summary>
/// <typeparam name="TEntity">Entity type</typeparam>
public interface IRepository<TEntity> where TEntity : class
{
    /// <summary>
    /// Get entity by ID
    /// </summary>
    Task<TEntity?> GetByIdAsync(int id);

    /// <summary>
    /// Get all entities
    /// </summary>
    Task<IEnumerable<TEntity>> GetAllAsync();

    /// <summary>
    /// Find entities matching predicate
    /// </summary>
    Task<IEnumerable<TEntity>> FindAsync(Expression<Func<TEntity, bool>> predicate);

    /// <summary>
    /// Get single entity matching predicate
    /// </summary>
    Task<TEntity?> FirstOrDefaultAsync(Expression<Func<TEntity, bool>> predicate);

    /// <summary>
    /// Add new entity
    /// </summary>
    Task<TEntity> AddAsync(TEntity entity);

    /// <summary>
    /// Add multiple entities
    /// </summary>
    Task AddRangeAsync(IEnumerable<TEntity> entities);

    /// <summary>
    /// Update entity
    /// </summary>
    void Update(TEntity entity);

    /// <summary>
    /// Update multiple entities
    /// </summary>
    void UpdateRange(IEnumerable<TEntity> entities);

    /// <summary>
    /// Delete entity
    /// </summary>
    void Delete(TEntity entity);

    /// <summary>
    /// Delete multiple entities
    /// </summary>
    void DeleteRange(IEnumerable<TEntity> entities);

    /// <summary>
    /// Count entities matching predicate
    /// </summary>
    Task<int> CountAsync(Expression<Func<TEntity, bool>>? predicate = null);

    /// <summary>
    /// Check if any entity matches predicate
    /// </summary>
    Task<bool> AnyAsync(Expression<Func<TEntity, bool>> predicate);
}








