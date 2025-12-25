namespace QRganize.Core.Interfaces;

/// <summary>
/// Factory interface for creating UnitOfWork instances
/// </summary>
public interface IUnitOfWorkFactory
{
    /// <summary>
    /// Create a new UnitOfWork instance
    /// </summary>
    IUnitOfWork Create();
}








