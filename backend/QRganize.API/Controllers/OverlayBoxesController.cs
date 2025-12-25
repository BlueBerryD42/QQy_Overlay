using Microsoft.AspNetCore.Mvc;
using QRganize.API.DTOs;
using QRganize.Core.Entities;
using QRganize.Core.Interfaces;

namespace QRganize.API.Controllers;

[ApiController]
[Route("api/overlay-boxes")]
public class OverlayBoxesController : ControllerBase
{
    private readonly IUnitOfWorkFactory _unitOfWorkFactory;

    public OverlayBoxesController(IUnitOfWorkFactory unitOfWorkFactory)
    {
        _unitOfWorkFactory = unitOfWorkFactory;
    }

    // GET: api/pages/5/overlay-boxes
    [HttpGet("~/api/pages/{pageId}/overlay-boxes")]
    public async Task<ActionResult<IEnumerable<OverlayBoxDto>>> GetOverlayBoxesByPageId(int pageId)
    {
        using var uow = _unitOfWorkFactory.Create();
        var overlayBoxes = await uow.OverlayBoxes.FindAsync(ob => ob.PageId == pageId);

        var result = overlayBoxes.Select(ob => new OverlayBoxDto
        {
            OverlayId = ob.OverlayId,
            PageId = ob.PageId,
            X = ob.X,
            Y = ob.Y,
            Width = ob.Width,
            Height = ob.Height,
            Rotation = ob.Rotation,
            ZIndex = ob.ZIndex,
            OriginalText = ob.OriginalText,
            TranslatedText = ob.TranslatedText,
            IsVerified = ob.IsVerified,
            CreatedAt = ob.CreatedAt,
            UpdatedAt = ob.UpdatedAt
        }).ToList();

        return Ok(result);
    }

    // POST: api/overlay-boxes
    [HttpPost]
    public async Task<ActionResult<OverlayBoxDto>> CreateOverlayBox(CreateOverlayBoxDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();

        var overlayBox = new OverlayBox
        {
            PageId = dto.PageId,
            X = dto.X,
            Y = dto.Y,
            Width = dto.Width,
            Height = dto.Height,
            Rotation = dto.Rotation,
            ZIndex = dto.ZIndex,
            OriginalText = dto.OriginalText,
            TranslatedText = dto.TranslatedText,
            IsVerified = dto.IsVerified,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        await uow.OverlayBoxes.AddAsync(overlayBox);
        await uow.SaveChangesAsync();

        var result = new OverlayBoxDto
        {
            OverlayId = overlayBox.OverlayId,
            PageId = overlayBox.PageId,
            X = overlayBox.X,
            Y = overlayBox.Y,
            Width = overlayBox.Width,
            Height = overlayBox.Height,
            Rotation = overlayBox.Rotation,
            ZIndex = overlayBox.ZIndex,
            OriginalText = overlayBox.OriginalText,
            TranslatedText = overlayBox.TranslatedText,
            IsVerified = overlayBox.IsVerified,
            CreatedAt = overlayBox.CreatedAt,
            UpdatedAt = overlayBox.UpdatedAt
        };

        return CreatedAtAction(nameof(GetOverlayBoxesByPageId), new { pageId = overlayBox.PageId }, result);
    }

    // PUT: api/overlay-boxes/5
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateOverlayBox(int id, CreateOverlayBoxDto dto)
    {
        using var uow = _unitOfWorkFactory.Create();
        var overlayBox = await uow.OverlayBoxes.GetByIdAsync(id);

        if (overlayBox == null)
        {
            return NotFound();
        }

        overlayBox.PageId = dto.PageId;
        overlayBox.X = dto.X;
        overlayBox.Y = dto.Y;
        overlayBox.Width = dto.Width;
        overlayBox.Height = dto.Height;
        overlayBox.Rotation = dto.Rotation;
        overlayBox.ZIndex = dto.ZIndex;
        overlayBox.OriginalText = dto.OriginalText;
        overlayBox.TranslatedText = dto.TranslatedText;
        overlayBox.IsVerified = dto.IsVerified;
        overlayBox.UpdatedAt = DateTime.UtcNow;

        uow.OverlayBoxes.Update(overlayBox);
        await uow.SaveChangesAsync();

        return NoContent();
    }

    // DELETE: api/overlay-boxes/5
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteOverlayBox(int id)
    {
        using var uow = _unitOfWorkFactory.Create();
        var overlayBox = await uow.OverlayBoxes.GetByIdAsync(id);

        if (overlayBox == null)
        {
            return NotFound();
        }

        uow.OverlayBoxes.Delete(overlayBox);
        await uow.SaveChangesAsync();

        return NoContent();
    }

    // DELETE: api/pages/5/overlay-boxes
    [HttpDelete("~/api/pages/{pageId}/overlay-boxes")]
    public async Task<IActionResult> DeleteOverlayBoxesByPageId(int pageId)
    {
        using var uow = _unitOfWorkFactory.Create();
        var overlayBoxes = await uow.OverlayBoxes.FindAsync(ob => ob.PageId == pageId);

        uow.OverlayBoxes.DeleteRange(overlayBoxes);
        await uow.SaveChangesAsync();

        return NoContent();
    }
}








