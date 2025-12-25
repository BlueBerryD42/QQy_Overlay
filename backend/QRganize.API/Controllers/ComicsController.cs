using Microsoft.AspNetCore.Mvc;
using QRganize.API.DTOs;
using QRganize.Core.Entities;
using QRganize.Core.Interfaces;
using System.Linq.Expressions;

namespace QRganize.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ComicsController : ControllerBase
{
    private readonly IUnitOfWorkFactory _unitOfWorkFactory;

    public ComicsController(IUnitOfWorkFactory unitOfWorkFactory)
    {
        _unitOfWorkFactory = unitOfWorkFactory;
    }

    // GET: api/comics
    [HttpGet]
    public async Task<ActionResult<IEnumerable<ComicDto>>> GetComics(
        [FromQuery] string? status,
        [FromQuery] string? search,
        [FromQuery] int? limit,
        [FromQuery] int? offset)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comics = await uow.Comics.GetAllAsync();

        // Filter by status
        if (!string.IsNullOrEmpty(status))
        {
            comics = comics.Where(c => c.Status == status);
        }

        // Search
        if (!string.IsNullOrEmpty(search))
        {
            var searchLower = search.ToLower();
            comics = comics.Where(c =>
                c.Title.ToLower().Contains(searchLower) ||
                (c.AlternativeTitle != null && c.AlternativeTitle.ToLower().Contains(searchLower)) ||
                (c.Description != null && c.Description.ToLower().Contains(searchLower)));
        }

        // Pagination
        if (offset.HasValue)
        {
            comics = comics.Skip(offset.Value);
        }
        if (limit.HasValue)
        {
            comics = comics.Take(limit.Value);
        }

        var result = comics.Select(c => new ComicDto
        {
            ComicId = c.ComicId,
            Title = c.Title,
            AlternativeTitle = c.AlternativeTitle,
            Description = c.Description,
            ManagedPath = c.ManagedPath,
            CoverImagePath = c.CoverImagePath,
            CoverPageId = c.CoverPageId,
            Status = c.Status,
            Rating = c.Rating,
            CreatedAt = c.CreatedAt,
            UpdatedAt = c.UpdatedAt
        }).ToList();

        return Ok(result);
    }

    // GET: api/comics/5
    [HttpGet("{id}")]
    public async Task<ActionResult<ComicDto>> GetComic(int id)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comic = await uow.Comics.GetByIdAsync(id);

        if (comic == null)
        {
            return NotFound();
        }

        var dto = new ComicDto
        {
            ComicId = comic.ComicId,
            Title = comic.Title,
            AlternativeTitle = comic.AlternativeTitle,
            Description = comic.Description,
            ManagedPath = comic.ManagedPath,
            CoverImagePath = comic.CoverImagePath,
            CoverPageId = comic.CoverPageId,
            Status = comic.Status,
            Rating = comic.Rating,
            CreatedAt = comic.CreatedAt,
            UpdatedAt = comic.UpdatedAt
        };

        return Ok(dto);
    }

    // POST: api/comics
    [HttpPost]
    public async Task<ActionResult<ComicDto>> CreateComic(CreateComicDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();

        var comic = new Comic
        {
            Title = dto.Title,
            AlternativeTitle = dto.AlternativeTitle,
            Description = dto.Description,
            ManagedPath = dto.ManagedPath,
            CoverImagePath = dto.CoverImagePath,
            CoverPageId = dto.CoverPageId,
            Status = dto.Status,
            Rating = dto.Rating,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        await uow.Comics.AddAsync(comic);
        await uow.SaveChangesAsync();

        var result = new ComicDto
        {
            ComicId = comic.ComicId,
            Title = comic.Title,
            AlternativeTitle = comic.AlternativeTitle,
            Description = comic.Description,
            ManagedPath = comic.ManagedPath,
            CoverImagePath = comic.CoverImagePath,
            CoverPageId = comic.CoverPageId,
            Status = comic.Status,
            Rating = comic.Rating,
            CreatedAt = comic.CreatedAt,
            UpdatedAt = comic.UpdatedAt
        };

        return CreatedAtAction(nameof(GetComic), new { id = comic.ComicId }, result);
    }

    // PUT: api/comics/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateComic(int id, UpdateComicDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comic = await uow.Comics.GetByIdAsync(id);

        if (comic == null)
        {
            return NotFound();
        }

        if (dto.Title != null) comic.Title = dto.Title;
        if (dto.AlternativeTitle != null) comic.AlternativeTitle = dto.AlternativeTitle;
        if (dto.Description != null) comic.Description = dto.Description;
        if (dto.ManagedPath != null) comic.ManagedPath = dto.ManagedPath;
        if (dto.CoverImagePath != null) comic.CoverImagePath = dto.CoverImagePath;
        if (dto.CoverPageId.HasValue) comic.CoverPageId = dto.CoverPageId;
        if (dto.Status != null) comic.Status = dto.Status;
        if (dto.Rating.HasValue) comic.Rating = dto.Rating;
        comic.UpdatedAt = DateTime.UtcNow;

        uow.Comics.Update(comic);
        await uow.SaveChangesAsync();

        return NoContent();
    }

    // DELETE: api/comics/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteComic(int id)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comic = await uow.Comics.GetByIdAsync(id);

        if (comic == null)
        {
            return NotFound();
        }

        uow.Comics.Delete(comic);
        await uow.SaveChangesAsync();

        return NoContent();
    }

    // POST: api/comics/5/tags
    [HttpPost("{id}/tags")]
    public async Task<IActionResult> LinkTag(int id, [FromBody] LinkTagDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comic = await uow.Comics.GetByIdAsync(id);
        var tag = await uow.Tags.GetByIdAsync(dto.TagId);

        if (comic == null || tag == null)
        {
            return NotFound();
        }

        var comicTag = new ComicTag
        {
            ComicId = id,
            TagId = dto.TagId
        };

        await uow.ComicTags.AddAsync(comicTag);
        await uow.SaveChangesAsync();

        return NoContent();
    }

    // DELETE: api/comics/5/tags/3
    [HttpDelete("{id}/tags/{tagId}")]
    public async Task<IActionResult> UnlinkTag(int id, int tagId)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comicTag = await uow.ComicTags.FirstOrDefaultAsync(ct => ct.ComicId == id && ct.TagId == tagId);

        if (comicTag == null)
        {
            return NotFound();
        }

        uow.ComicTags.Delete(comicTag);
        await uow.SaveChangesAsync();

        return NoContent();
    }

    // POST: api/comics/5/creators
    [HttpPost("{id}/creators")]
    public async Task<IActionResult> LinkCreator(int id, [FromBody] LinkCreatorDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comic = await uow.Comics.GetByIdAsync(id);
        var creator = await uow.Creators.GetByIdAsync(dto.CreatorId);

        if (comic == null || creator == null)
        {
            return NotFound();
        }

        var comicCreator = new ComicCreator
        {
            ComicId = id,
            CreatorId = dto.CreatorId
        };

        await uow.ComicCreators.AddAsync(comicCreator);
        await uow.SaveChangesAsync();

        return NoContent();
    }

    // DELETE: api/comics/5/creators/3
    [HttpDelete("{id}/creators/{creatorId}")]
    public async Task<IActionResult> UnlinkCreator(int id, int creatorId)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comicCreator = await uow.ComicCreators.FirstOrDefaultAsync(cc => cc.ComicId == id && cc.CreatorId == creatorId);

        if (comicCreator == null)
        {
            return NotFound();
        }

        uow.ComicCreators.Delete(comicCreator);
        await uow.SaveChangesAsync();

        return NoContent();
    }

    // POST: api/comics/5/sources
    [HttpPost("{id}/sources")]
    public async Task<IActionResult> LinkSource(int id, [FromBody] LinkSourceDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comic = await uow.Comics.GetByIdAsync(id);
        var source = await uow.Sources.GetByIdAsync(dto.SourceId);

        if (comic == null || source == null)
        {
            return NotFound();
        }

        var comicSource = new ComicSource
        {
            ComicId = id,
            SourceId = dto.SourceId
        };

        await uow.ComicSources.AddAsync(comicSource);
        await uow.SaveChangesAsync();

        return NoContent();
    }

    // GET: api/comics/5/tags
    [HttpGet("{id}/tags")]
    public async Task<ActionResult<IEnumerable<TagDto>>> GetComicTags(int id)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comicTags = await uow.ComicTags.FindAsync(ct => ct.ComicId == id);
        var tagIds = comicTags.Select(ct => ct.TagId).ToList();
        var tags = await uow.Tags.FindAsync(t => tagIds.Contains(t.TagId));

        var result = tags.Select(t => new TagDto
        {
            TagId = t.TagId,
            GroupId = t.GroupId,
            Name = t.Name,
            Description = t.Description,
            IsSensitive = t.IsSensitive,
            CreatedAt = t.CreatedAt
        }).ToList();

        return Ok(result);
    }

    // GET: api/comics/5/creators
    [HttpGet("{id}/creators")]
    public async Task<ActionResult<IEnumerable<CreatorDto>>> GetComicCreators(int id)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comicCreators = await uow.ComicCreators.FindAsync(cc => cc.ComicId == id);
        var creatorIds = comicCreators.Select(cc => cc.CreatorId).ToList();
        var creators = await uow.Creators.FindAsync(c => creatorIds.Contains(c.CreatorId));

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

    // GET: api/comics/5/sources
    [HttpGet("{id}/sources")]
    public async Task<ActionResult<IEnumerable<SourceDto>>> GetComicSources(int id)
    {
        using var uow = _unitOfWorkFactory.Create();
        var comicSources = await uow.ComicSources.FindAsync(cs => cs.ComicId == id);
        var sourceIds = comicSources.Select(cs => cs.SourceId).ToList();
        var sources = await uow.Sources.FindAsync(s => sourceIds.Contains(s.SourceId));

        var result = sources.Select(s => new SourceDto
        {
            SourceId = s.SourceId,
            Platform = s.Platform,
            SourceUrl = s.SourceUrl,
            AuthorHandle = s.AuthorHandle,
            PostId = s.PostId,
            Description = s.Description,
            DiscoveredAt = s.DiscoveredAt,
            IsPrimary = s.IsPrimary
        }).ToList();

        return Ok(result);
    }
}





