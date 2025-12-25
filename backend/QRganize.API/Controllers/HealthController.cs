using Microsoft.AspNetCore.Mvc;

namespace QRganize.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    /// <summary>
    /// Health check endpoint to test API connection
    /// </summary>
    /// <returns>Status information</returns>
    [HttpGet]
    public IActionResult Get()
    {
        return Ok(new
        {
            status = "ok",
            message = "API is running",
            timestamp = DateTime.UtcNow
        });
    }
}




