using Microsoft.AspNetCore.Mvc;
using QRganize.API.DTOs;
using QRganize.Core.Entities;
using QRganize.Core.Interfaces;

namespace QRganize.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PagesController : ControllerBase
{
    private readonly IUnitOfWorkFactory _unitOfWorkFactory;

    public PagesController(IUnitOfWorkFactory unitOfWorkFactory)
    {
        _unitOfWorkFactory = unitOfWorkFactory;
    }

    // GET: api/pages/5
    [HttpGet("{id}")]
    public async Task<ActionResult<PageDto>> GetPage(int id)
    {
        using var uow = _unitOfWorkFactory.Create();
        var page = await uow.Pages.GetByIdAsync(id);

        if (page == null)
        {
            return NotFound();
        }

        var dto = new PageDto
        {
            PageId = page.PageId,
            ComicId = page.ComicId,
            PageNumber = page.PageNumber,
            StoragePath = page.StoragePath,
            FileName = page.FileName,
            FileExtension = page.FileExtension,
            FileSizeBytes = page.FileSizeBytes,
            Width = page.Width,
            Height = page.Height,
            Dpi = page.Dpi,
            ColorProfile = page.ColorProfile,
            ImageHash = page.ImageHash,
            ThumbnailPath = page.ThumbnailPath,
            CreatedAt = page.CreatedAt
        };

        return Ok(dto);
    }

    // GET: api/comics/5/pages
    [HttpGet("~/api/comics/{comicId}/pages")]
    public async Task<ActionResult<IEnumerable<PageDto>>> GetPagesByComicId(int comicId)
    {
        using var uow = _unitOfWorkFactory.Create();
        var pages = await uow.Pages.FindAsync(p => p.ComicId == comicId);

        var result = pages.OrderBy(p => p.PageNumber).Select(p => new PageDto
        {
            PageId = p.PageId,
            ComicId = p.ComicId,
            PageNumber = p.PageNumber,
            StoragePath = p.StoragePath,
            FileName = p.FileName,
            FileExtension = p.FileExtension,
            FileSizeBytes = p.FileSizeBytes,
            Width = p.Width,
            Height = p.Height,
            Dpi = p.Dpi,
            ColorProfile = p.ColorProfile,
            ImageHash = p.ImageHash,
            ThumbnailPath = p.ThumbnailPath,
            CreatedAt = p.CreatedAt
        }).ToList();

        return Ok(result);
    }

    // POST: api/pages
    [HttpPost]
    public async Task<ActionResult<PageDto>> CreatePage(CreatePageDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();

        var page = new Page
        {
            ComicId = dto.ComicId,
            PageNumber = dto.PageNumber,
            StoragePath = dto.StoragePath,
            FileName = dto.FileName,
            FileExtension = dto.FileExtension,
            FileSizeBytes = dto.FileSizeBytes,
            Width = dto.Width,
            Height = dto.Height,
            Dpi = dto.Dpi,
            ColorProfile = dto.ColorProfile,
            ImageHash = dto.ImageHash,
            ThumbnailPath = dto.ThumbnailPath,
            CreatedAt = DateTime.UtcNow
        };

        await uow.Pages.AddAsync(page);
        await uow.SaveChangesAsync();

        var result = new PageDto
        {
            PageId = page.PageId,
            ComicId = page.ComicId,
            PageNumber = page.PageNumber,
            StoragePath = page.StoragePath,
            FileName = page.FileName,
            FileExtension = page.FileExtension,
            FileSizeBytes = page.FileSizeBytes,
            Width = page.Width,
            Height = page.Height,
            Dpi = page.Dpi,
            ColorProfile = page.ColorProfile,
            ImageHash = page.ImageHash,
            ThumbnailPath = page.ThumbnailPath,
            CreatedAt = page.CreatedAt
        };

        return CreatedAtAction(nameof(GetPage), new { id = page.PageId }, result);
    }

    // PUT: api/pages/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdatePage(int id, CreatePageDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();
        var page = await uow.Pages.GetByIdAsync(id);

        if (page == null)
        {
            return NotFound();
        }

        page.ComicId = dto.ComicId;
        page.PageNumber = dto.PageNumber;
        page.StoragePath = dto.StoragePath;
        page.FileName = dto.FileName;
        page.FileExtension = dto.FileExtension;
        page.FileSizeBytes = dto.FileSizeBytes;
        page.Width = dto.Width;
        page.Height = dto.Height;
        page.Dpi = dto.Dpi;
        page.ColorProfile = dto.ColorProfile;
        page.ImageHash = dto.ImageHash;
        page.ThumbnailPath = dto.ThumbnailPath;

        uow.Pages.Update(page);
        await uow.SaveChangesAsync();

        return NoContent();
    }

    // DELETE: api/pages/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeletePage(int id)
    {
        using var uow = _unitOfWorkFactory.Create();
        var page = await uow.Pages.GetByIdAsync(id);

        if (page == null)
        {
            return NotFound();
        }

        uow.Pages.Delete(page);
        await uow.SaveChangesAsync();

        return NoContent();
    }
}








