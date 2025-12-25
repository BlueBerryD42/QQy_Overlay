using Microsoft.EntityFrameworkCore;
using QRganize.Core.Entities;

namespace QRganize.Infrastructure.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    // DbSets
    public DbSet<Comic> Comics { get; set; }
    public DbSet<Page> Pages { get; set; }
    public DbSet<OverlayBox> OverlayBoxes { get; set; }
    public DbSet<Tag> Tags { get; set; }
    public DbSet<TagGroup> TagGroups { get; set; }
    public DbSet<Creator> Creators { get; set; }
    public DbSet<Source> Sources { get; set; }
    public DbSet<ComicTag> ComicTags { get; set; }
    public DbSet<ComicCreator> ComicCreators { get; set; }
    public DbSet<ComicSource> ComicSources { get; set; }
    public DbSet<TextStyle> TextStyles { get; set; }
    public DbSet<Engine> Engines { get; set; }
    public DbSet<EngineHistory> EngineHistories { get; set; }
    public DbSet<DownloadSource> DownloadSources { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Comic configuration
        modelBuilder.Entity<Comic>(entity =>
        {
            entity.ToTable("comic");
            entity.HasKey(e => e.ComicId);
            entity.Property(e => e.ComicId).HasColumnName("comic_id");
            entity.Property(e => e.Title).HasColumnName("title").IsRequired().HasMaxLength(500);
            entity.Property(e => e.AlternativeTitle).HasColumnName("alternative_title").HasMaxLength(500);
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.ManagedPath).HasColumnName("managed_path").IsRequired().HasMaxLength(1000);
            entity.Property(e => e.CoverImagePath).HasColumnName("cover_image_path").HasMaxLength(1000);
            entity.Property(e => e.CoverPageId).HasColumnName("cover_page_id");
            entity.Property(e => e.Status).HasColumnName("status").HasMaxLength(50).HasDefaultValue("active");
            entity.Property(e => e.Rating).HasColumnName("rating");
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").IsRequired();

            entity.HasOne(e => e.CoverPage)
                .WithMany()
                .HasForeignKey(e => e.CoverPageId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Page configuration
        modelBuilder.Entity<Page>(entity =>
        {
            entity.ToTable("page");
            entity.HasKey(e => e.PageId);
            entity.Property(e => e.PageId).HasColumnName("page_id");
            entity.Property(e => e.ComicId).HasColumnName("comic_id").IsRequired();
            entity.Property(e => e.PageNumber).HasColumnName("page_number").IsRequired();
            entity.Property(e => e.StoragePath).HasColumnName("storage_path").IsRequired().HasMaxLength(1000);
            entity.Property(e => e.FileName).HasColumnName("file_name").IsRequired().HasMaxLength(500);
            entity.Property(e => e.FileExtension).HasColumnName("file_extension").HasMaxLength(50);
            entity.Property(e => e.FileSizeBytes).HasColumnName("file_size_bytes");
            entity.Property(e => e.Width).HasColumnName("width");
            entity.Property(e => e.Height).HasColumnName("height");
            entity.Property(e => e.Dpi).HasColumnName("dpi");
            entity.Property(e => e.ColorProfile).HasColumnName("color_profile").HasMaxLength(100);
            entity.Property(e => e.ImageHash).HasColumnName("image_hash").HasMaxLength(64);
            entity.Property(e => e.ThumbnailPath).HasColumnName("thumbnail_path").HasMaxLength(1000);
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();

            entity.HasOne(e => e.Comic)
                .WithMany(c => c.Pages)
                .HasForeignKey(e => e.ComicId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // OverlayBox configuration
        modelBuilder.Entity<OverlayBox>(entity =>
        {
            entity.ToTable("overlay_box");
            entity.HasKey(e => e.OverlayId);
            entity.Property(e => e.OverlayId).HasColumnName("overlay_id");
            entity.Property(e => e.PageId).HasColumnName("page_id").IsRequired();
            entity.Property(e => e.X).HasColumnName("x").IsRequired();
            entity.Property(e => e.Y).HasColumnName("y").IsRequired();
            entity.Property(e => e.Width).HasColumnName("width").IsRequired();
            entity.Property(e => e.Height).HasColumnName("height").IsRequired();
            entity.Property(e => e.Rotation).HasColumnName("rotation").HasDefaultValue(0);
            entity.Property(e => e.ZIndex).HasColumnName("z_index").HasDefaultValue(0);
            entity.Property(e => e.OriginalText).HasColumnName("original_text");
            entity.Property(e => e.TranslatedText).HasColumnName("translated_text");
            entity.Property(e => e.IsVerified).HasColumnName("is_verified").HasDefaultValue(false);
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").IsRequired();

            entity.HasOne(e => e.Page)
                .WithMany(p => p.OverlayBoxes)
                .HasForeignKey(e => e.PageId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // TagGroup configuration
        modelBuilder.Entity<TagGroup>(entity =>
        {
            entity.ToTable("tag_group");
            entity.HasKey(e => e.GroupId);
            entity.Property(e => e.GroupId).HasColumnName("group_id");
            entity.Property(e => e.Name).HasColumnName("name").IsRequired().HasMaxLength(200);
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();
        });

        // Tag configuration
        modelBuilder.Entity<Tag>(entity =>
        {
            entity.ToTable("tag");
            entity.HasKey(e => e.TagId);
            entity.Property(e => e.TagId).HasColumnName("tag_id");
            entity.Property(e => e.GroupId).HasColumnName("group_id");
            entity.Property(e => e.Name).HasColumnName("name").IsRequired().HasMaxLength(200);
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.IsSensitive).HasColumnName("is_sensitive").HasDefaultValue(false);
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();

            entity.HasOne(e => e.TagGroup)
                .WithMany(g => g.Tags)
                .HasForeignKey(e => e.GroupId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // Creator configuration
        modelBuilder.Entity<Creator>(entity =>
        {
            entity.ToTable("creator");
            entity.HasKey(e => e.CreatorId);
            entity.Property(e => e.CreatorId).HasColumnName("creator_id");
            entity.Property(e => e.Name).HasColumnName("name").IsRequired().HasMaxLength(200);
            entity.Property(e => e.Role).HasColumnName("role").HasMaxLength(100);
            entity.Property(e => e.WebsiteUrl).HasColumnName("website_url").HasMaxLength(500);
            entity.Property(e => e.SocialLink).HasColumnName("social_link").HasMaxLength(500);
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();
        });

        // Source configuration
        modelBuilder.Entity<Source>(entity =>
        {
            entity.ToTable("source");
            entity.HasKey(e => e.SourceId);
            entity.Property(e => e.SourceId).HasColumnName("source_id");
            entity.Property(e => e.Platform).HasColumnName("platform").HasMaxLength(100);
            entity.Property(e => e.SourceUrl).HasColumnName("source_url").HasMaxLength(1000);
            entity.Property(e => e.AuthorHandle).HasColumnName("author_handle").HasMaxLength(200);
            entity.Property(e => e.PostId).HasColumnName("post_id").HasMaxLength(200);
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.DiscoveredAt).HasColumnName("discovered_at").IsRequired();
            entity.Property(e => e.IsPrimary).HasColumnName("is_primary").HasDefaultValue(false);
        });

        // ComicTag (many-to-many)
        modelBuilder.Entity<ComicTag>(entity =>
        {
            entity.ToTable("comic_tag");
            entity.HasKey(e => new { e.ComicId, e.TagId });
            entity.Property(e => e.ComicId).HasColumnName("comic_id");
            entity.Property(e => e.TagId).HasColumnName("tag_id");

            entity.HasOne(e => e.Comic)
                .WithMany(c => c.ComicTags)
                .HasForeignKey(e => e.ComicId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Tag)
                .WithMany(t => t.ComicTags)
                .HasForeignKey(e => e.TagId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // ComicCreator (many-to-many)
        modelBuilder.Entity<ComicCreator>(entity =>
        {
            entity.ToTable("comic_creator");
            entity.HasKey(e => new { e.ComicId, e.CreatorId });
            entity.Property(e => e.ComicId).HasColumnName("comic_id");
            entity.Property(e => e.CreatorId).HasColumnName("creator_id");

            entity.HasOne(e => e.Comic)
                .WithMany(c => c.ComicCreators)
                .HasForeignKey(e => e.ComicId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Creator)
                .WithMany(c => c.ComicCreators)
                .HasForeignKey(e => e.CreatorId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // ComicSource (many-to-many)
        modelBuilder.Entity<ComicSource>(entity =>
        {
            entity.ToTable("comic_source");
            entity.HasKey(e => new { e.ComicId, e.SourceId });
            entity.Property(e => e.ComicId).HasColumnName("comic_id");
            entity.Property(e => e.SourceId).HasColumnName("source_id");

            entity.HasOne(e => e.Comic)
                .WithMany(c => c.ComicSources)
                .HasForeignKey(e => e.ComicId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Source)
                .WithMany(s => s.ComicSources)
                .HasForeignKey(e => e.SourceId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // TextStyle configuration
        modelBuilder.Entity<TextStyle>(entity =>
        {
            entity.ToTable("text_style");
            entity.HasKey(e => e.TextStyleId);
            entity.Property(e => e.TextStyleId).HasColumnName("text_style_id");
            entity.Property(e => e.FontFamily).HasColumnName("font_family").IsRequired().HasMaxLength(100);
            entity.Property(e => e.FontSize).HasColumnName("font_size").IsRequired();
            entity.Property(e => e.FontWeight).HasColumnName("font_weight").HasMaxLength(50).HasDefaultValue("normal");
            entity.Property(e => e.FontStyle).HasColumnName("font_style").HasMaxLength(50).HasDefaultValue("normal");
            entity.Property(e => e.Color).HasColumnName("color").HasMaxLength(50);
            entity.Property(e => e.BackgroundColor).HasColumnName("background_color").HasMaxLength(50);
            entity.Property(e => e.LetterSpacing).HasColumnName("letter_spacing");
            entity.Property(e => e.LineHeight).HasColumnName("line_height");
            entity.Property(e => e.TextAlign).HasColumnName("text_align").HasMaxLength(50);
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();
        });

        // Engine configuration
        modelBuilder.Entity<Engine>(entity =>
        {
            entity.ToTable("engine");
            entity.HasKey(e => e.EngineId);
            entity.Property(e => e.EngineId).HasColumnName("engine_id");
            entity.Property(e => e.Name).HasColumnName("name").IsRequired().HasMaxLength(200);
            entity.Property(e => e.Type).HasColumnName("type").IsRequired().HasMaxLength(100);
            entity.Property(e => e.ApiEndpoint).HasColumnName("api_endpoint").HasMaxLength(500);
            entity.Property(e => e.ApiKey).HasColumnName("api_key").HasMaxLength(500);
            entity.Property(e => e.Configuration).HasColumnName("configuration");
            entity.Property(e => e.IsActive).HasColumnName("is_active").HasDefaultValue(false);
            entity.Property(e => e.CreatedAt).HasColumnName("created_at").IsRequired();
            entity.Property(e => e.UpdatedAt).HasColumnName("updated_at").IsRequired();
        });

        // EngineHistory configuration
        modelBuilder.Entity<EngineHistory>(entity =>
        {
            entity.ToTable("engine_history");
            entity.HasKey(e => e.HistoryId);
            entity.Property(e => e.HistoryId).HasColumnName("history_id");
            entity.Property(e => e.EngineId).HasColumnName("engine_id").IsRequired();
            entity.Property(e => e.OverlayBoxId).HasColumnName("overlay_box_id");
            entity.Property(e => e.OriginalText).HasColumnName("original_text");
            entity.Property(e => e.TranslatedText).HasColumnName("translated_text");
            entity.Property(e => e.Status).HasColumnName("status").HasMaxLength(50);
            entity.Property(e => e.ErrorMessage).HasColumnName("error_message");
            entity.Property(e => e.ProcessedAt).HasColumnName("processed_at").IsRequired();

            entity.HasOne(e => e.Engine)
                .WithMany(eng => eng.EngineHistories)
                .HasForeignKey(e => e.EngineId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.OverlayBox)
                .WithMany()
                .HasForeignKey(e => e.OverlayBoxId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // DownloadSource configuration
        modelBuilder.Entity<DownloadSource>(entity =>
        {
            entity.ToTable("download_source");
            entity.HasKey(e => e.DownloadSourceId);
            entity.Property(e => e.DownloadSourceId).HasColumnName("download_source_id");
            entity.Property(e => e.Platform).HasColumnName("platform").HasMaxLength(100);
            entity.Property(e => e.SourceUrl).HasColumnName("source_url").HasMaxLength(1000);
            entity.Property(e => e.AuthorHandle).HasColumnName("author_handle").HasMaxLength(200);
            entity.Property(e => e.PostId).HasColumnName("post_id").HasMaxLength(200);
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.DiscoveredAt).HasColumnName("discovered_at").IsRequired();
            entity.Property(e => e.IsPrimary).HasColumnName("is_primary").HasDefaultValue(false);
        });
    }
}








