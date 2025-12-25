using Microsoft.AspNetCore.Mvc;
using QRganize.API.DTOs;
using QRganize.Core.Entities;
using QRganize.Core.Interfaces;

namespace QRganize.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CreatorsController : ControllerBase
{
    private readonly IUnitOfWorkFactory _unitOfWorkFactory;

    public CreatorsController(IUnitOfWorkFactory unitOfWorkFactory)
    {
        _unitOfWorkFactory = unitOfWorkFactory;
    }

    // GET: api/creators
    [HttpGet]
    public async Task<ActionResult<IEnumerable<CreatorDto>>> GetCreators()
    {
        using var uow = _unitOfWorkFactory.Create();
        var creators = await uow.Creators.GetAllAsync();

        var result = creators.Select(c => new CreatorDto
        {
            CreatorId = c.CreatorId,
            Name = c.Name,
            Role = c.Role,
            WebsiteUrl = c.WebsiteUrl,
            SocialLink = c.SocialLink,
            CreatedAt = c.CreatedAt
        }).ToList();

        return Ok(result);
    }

    // POST: api/creators
    [HttpPost]
    public async Task<ActionResult<CreatorDto>> CreateCreator(CreateCreatorDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();

        var creator = new Creator
        {
            Name = dto.Name,
            Role = dto.Role,
            WebsiteUrl = dto.WebsiteUrl,
            SocialLink = dto.SocialLink,
            CreatedAt = DateTime.UtcNow
        };

        await uow.Creators.AddAsync(creator);
        await uow.SaveChangesAsync();

        var result = new CreatorDto
        {
            CreatorId = creator.CreatorId,
            Name = creator.Name,
            Role = creator.Role,
            WebsiteUrl = creator.WebsiteUrl,
            SocialLink = creator.SocialLink,
            CreatedAt = creator.CreatedAt
        };

        return CreatedAtAction(nameof(GetCreators), new { id = creator.CreatorId }, result);
    }

    // PUT: api/creators/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateCreator(int id, UpdateCreatorDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();
        var creator = await uow.Creators.GetByIdAsync(id);

        if (creator == null)
        {
            return NotFound();
        }

        if (dto.Name != null) creator.Name = dto.Name;
        if (dto.Role != null) creator.Role = dto.Role;
        if (dto.WebsiteUrl != null) creator.WebsiteUrl = dto.WebsiteUrl;
        if (dto.SocialLink != null) creator.SocialLink = dto.SocialLink;

        uow.Creators.Update(creator);
        await uow.SaveChangesAsync();

        return NoContent();
    }
}

[ApiController]
[Route("api/[controller]")]
public class SourcesController : ControllerBase
{
    private readonly IUnitOfWorkFactory _unitOfWorkFactory;

    public SourcesController(IUnitOfWorkFactory unitOfWorkFactory)
    {
        _unitOfWorkFactory = unitOfWorkFactory;
    }

    // POST: api/sources
    [HttpPost]
    public async Task<ActionResult<SourceDto>> CreateSource(CreateSourceDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();

        var source = new Source
        {
            Platform = dto.Platform,
            SourceUrl = dto.SourceUrl,
            AuthorHandle = dto.AuthorHandle,
            PostId = dto.PostId,
            Description = dto.Description,
            DiscoveredAt = DateTime.UtcNow,
            IsPrimary = dto.IsPrimary
        };

        await uow.Sources.AddAsync(source);
        await uow.SaveChangesAsync();

        var result = new SourceDto
        {
            SourceId = source.SourceId,
            Platform = source.Platform,
            SourceUrl = source.SourceUrl,
            AuthorHandle = source.AuthorHandle,
            PostId = source.PostId,
            Description = source.Description,
            DiscoveredAt = source.DiscoveredAt,
            IsPrimary = source.IsPrimary
        };

        return CreatedAtAction(nameof(CreateSource), new { id = source.SourceId }, result);
    }

    // PUT: api/sources/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateSource(int id, UpdateSourceDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();
        var source = await uow.Sources.GetByIdAsync(id);

        if (source == null)
        {
            return NotFound();
        }

        if (dto.Platform != null) source.Platform = dto.Platform;
        if (dto.SourceUrl != null) source.SourceUrl = dto.SourceUrl;
        if (dto.AuthorHandle != null) source.AuthorHandle = dto.AuthorHandle;
        if (dto.PostId != null) source.PostId = dto.PostId;
        if (dto.Description != null) source.Description = dto.Description;
        if (dto.IsPrimary.HasValue) source.IsPrimary = dto.IsPrimary.Value;

        uow.Sources.Update(source);
        await uow.SaveChangesAsync();

        return NoContent();
    }
}





