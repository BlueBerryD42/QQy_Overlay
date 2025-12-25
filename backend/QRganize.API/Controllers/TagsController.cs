using Microsoft.AspNetCore.Mvc;
using QRganize.API.DTOs;
using QRganize.Core.Entities;
using QRganize.Core.Interfaces;

namespace QRganize.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TagsController : ControllerBase
{
    private readonly IUnitOfWorkFactory _unitOfWorkFactory;

    public TagsController(IUnitOfWorkFactory unitOfWorkFactory)
    {
        _unitOfWorkFactory = unitOfWorkFactory;
    }

    // GET: api/tags
    [HttpGet]
    public async Task<ActionResult<IEnumerable<TagDto>>> GetTags([FromQuery] int? groupId)
    {
        using var uow = _unitOfWorkFactory.Create();
        var tags = await uow.Tags.GetAllAsync();

        if (groupId.HasValue)
        {
            tags = tags.Where(t => t.GroupId == groupId.Value);
        }

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

    // POST: api/tags
    [HttpPost]
    public async Task<ActionResult<TagDto>> CreateTag(CreateTagDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();

        var tag = new Tag
        {
            GroupId = dto.GroupId,
            Name = dto.Name,
            Description = dto.Description,
            IsSensitive = dto.IsSensitive,
            CreatedAt = DateTime.UtcNow
        };

        await uow.Tags.AddAsync(tag);
        await uow.SaveChangesAsync();

        var result = new TagDto
        {
            TagId = tag.TagId,
            GroupId = tag.GroupId,
            Name = tag.Name,
            Description = tag.Description,
            IsSensitive = tag.IsSensitive,
            CreatedAt = tag.CreatedAt
        };

        return CreatedAtAction(nameof(GetTags), new { id = tag.TagId }, result);
    }
}

[ApiController]
[Route("api/tag-groups")]
public class TagGroupsController : ControllerBase
{
    private readonly IUnitOfWorkFactory _unitOfWorkFactory;

    public TagGroupsController(IUnitOfWorkFactory unitOfWorkFactory)
    {
        _unitOfWorkFactory = unitOfWorkFactory;
    }

    // GET: api/tag-groups
    [HttpGet]
    public async Task<ActionResult<IEnumerable<TagGroupDto>>> GetTagGroups()
    {
        using var uow = _unitOfWorkFactory.Create();
        var tagGroups = await uow.TagGroups.GetAllAsync();

        var result = tagGroups.Select(tg => new TagGroupDto
        {
            GroupId = tg.GroupId,
            Name = tg.Name,
            CreatedAt = tg.CreatedAt
        }).ToList();

        return Ok(result);
    }

    // POST: api/tag-groups
    [HttpPost]
    public async Task<ActionResult<TagGroupDto>> CreateTagGroup(CreateTagGroupDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();

        var tagGroup = new TagGroup
        {
            Name = dto.Name,
            CreatedAt = DateTime.UtcNow
        };

        await uow.TagGroups.AddAsync(tagGroup);
        await uow.SaveChangesAsync();

        var result = new TagGroupDto
        {
            GroupId = tagGroup.GroupId,
            Name = tagGroup.Name,
            CreatedAt = tagGroup.CreatedAt
        };

        return CreatedAtAction(nameof(GetTagGroups), new { id = tagGroup.GroupId }, result);
    }
}








