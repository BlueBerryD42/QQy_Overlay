using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace QRganize.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "creator",
                columns: table => new
                {
                    creator_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    role = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    website_url = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    social_link = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_creator", x => x.creator_id);
                });

            migrationBuilder.CreateTable(
                name: "download_source",
                columns: table => new
                {
                    download_source_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    platform = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    source_url = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    author_handle = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    post_id = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    discovered_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    is_primary = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_download_source", x => x.download_source_id);
                });

            migrationBuilder.CreateTable(
                name: "engine",
                columns: table => new
                {
                    engine_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    type = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    api_endpoint = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    api_key = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    configuration = table.Column<string>(type: "text", nullable: true),
                    is_active = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_engine", x => x.engine_id);
                });

            migrationBuilder.CreateTable(
                name: "source",
                columns: table => new
                {
                    source_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    platform = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    source_url = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    author_handle = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    post_id = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    discovered_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    is_primary = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_source", x => x.source_id);
                });

            migrationBuilder.CreateTable(
                name: "tag_group",
                columns: table => new
                {
                    group_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_tag_group", x => x.group_id);
                });

            migrationBuilder.CreateTable(
                name: "text_style",
                columns: table => new
                {
                    text_style_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    font_family = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    font_size = table.Column<double>(type: "double precision", nullable: false),
                    font_weight = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false, defaultValue: "normal"),
                    font_style = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false, defaultValue: "normal"),
                    color = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    background_color = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    letter_spacing = table.Column<double>(type: "double precision", nullable: true),
                    line_height = table.Column<double>(type: "double precision", nullable: true),
                    text_align = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_text_style", x => x.text_style_id);
                });

            migrationBuilder.CreateTable(
                name: "tag",
                columns: table => new
                {
                    tag_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    group_id = table.Column<int>(type: "integer", nullable: true),
                    name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    description = table.Column<string>(type: "text", nullable: true),
                    is_sensitive = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_tag", x => x.tag_id);
                    table.ForeignKey(
                        name: "FK_tag_tag_group_group_id",
                        column: x => x.group_id,
                        principalTable: "tag_group",
                        principalColumn: "group_id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "comic",
                columns: table => new
                {
                    comic_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    title = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    alternative_title = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    description = table.Column<string>(type: "text", nullable: true),
                    managed_path = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    cover_image_path = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    cover_page_id = table.Column<int>(type: "integer", nullable: true),
                    status = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false, defaultValue: "active"),
                    rating = table.Column<int>(type: "integer", nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_comic", x => x.comic_id);
                });

            migrationBuilder.CreateTable(
                name: "comic_creator",
                columns: table => new
                {
                    comic_id = table.Column<int>(type: "integer", nullable: false),
                    creator_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_comic_creator", x => new { x.comic_id, x.creator_id });
                    table.ForeignKey(
                        name: "FK_comic_creator_comic_comic_id",
                        column: x => x.comic_id,
                        principalTable: "comic",
                        principalColumn: "comic_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_comic_creator_creator_creator_id",
                        column: x => x.creator_id,
                        principalTable: "creator",
                        principalColumn: "creator_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "comic_source",
                columns: table => new
                {
                    comic_id = table.Column<int>(type: "integer", nullable: false),
                    source_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_comic_source", x => new { x.comic_id, x.source_id });
                    table.ForeignKey(
                        name: "FK_comic_source_comic_comic_id",
                        column: x => x.comic_id,
                        principalTable: "comic",
                        principalColumn: "comic_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_comic_source_source_source_id",
                        column: x => x.source_id,
                        principalTable: "source",
                        principalColumn: "source_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "comic_tag",
                columns: table => new
                {
                    comic_id = table.Column<int>(type: "integer", nullable: false),
                    tag_id = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_comic_tag", x => new { x.comic_id, x.tag_id });
                    table.ForeignKey(
                        name: "FK_comic_tag_comic_comic_id",
                        column: x => x.comic_id,
                        principalTable: "comic",
                        principalColumn: "comic_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_comic_tag_tag_tag_id",
                        column: x => x.tag_id,
                        principalTable: "tag",
                        principalColumn: "tag_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "page",
                columns: table => new
                {
                    page_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    comic_id = table.Column<int>(type: "integer", nullable: false),
                    page_number = table.Column<int>(type: "integer", nullable: false),
                    storage_path = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    file_name = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    file_extension = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    file_size_bytes = table.Column<int>(type: "integer", nullable: true),
                    width = table.Column<int>(type: "integer", nullable: true),
                    height = table.Column<int>(type: "integer", nullable: true),
                    dpi = table.Column<int>(type: "integer", nullable: true),
                    color_profile = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    image_hash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    thumbnail_path = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_page", x => x.page_id);
                    table.ForeignKey(
                        name: "FK_page_comic_comic_id",
                        column: x => x.comic_id,
                        principalTable: "comic",
                        principalColumn: "comic_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "overlay_box",
                columns: table => new
                {
                    overlay_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    page_id = table.Column<int>(type: "integer", nullable: false),
                    x = table.Column<double>(type: "double precision", nullable: false),
                    y = table.Column<double>(type: "double precision", nullable: false),
                    width = table.Column<double>(type: "double precision", nullable: false),
                    height = table.Column<double>(type: "double precision", nullable: false),
                    rotation = table.Column<double>(type: "double precision", nullable: false, defaultValue: 0.0),
                    z_index = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    original_text = table.Column<string>(type: "text", nullable: true),
                    translated_text = table.Column<string>(type: "text", nullable: true),
                    is_verified = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    created_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_overlay_box", x => x.overlay_id);
                    table.ForeignKey(
                        name: "FK_overlay_box_page_page_id",
                        column: x => x.page_id,
                        principalTable: "page",
                        principalColumn: "page_id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "engine_history",
                columns: table => new
                {
                    history_id = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    engine_id = table.Column<int>(type: "integer", nullable: false),
                    overlay_box_id = table.Column<int>(type: "integer", nullable: true),
                    original_text = table.Column<string>(type: "text", nullable: true),
                    translated_text = table.Column<string>(type: "text", nullable: true),
                    status = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    error_message = table.Column<string>(type: "text", nullable: true),
                    processed_at = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_engine_history", x => x.history_id);
                    table.ForeignKey(
                        name: "FK_engine_history_engine_engine_id",
                        column: x => x.engine_id,
                        principalTable: "engine",
                        principalColumn: "engine_id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_engine_history_overlay_box_overlay_box_id",
                        column: x => x.overlay_box_id,
                        principalTable: "overlay_box",
                        principalColumn: "overlay_id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_comic_cover_page_id",
                table: "comic",
                column: "cover_page_id");

            migrationBuilder.CreateIndex(
                name: "IX_comic_creator_creator_id",
                table: "comic_creator",
                column: "creator_id");

            migrationBuilder.CreateIndex(
                name: "IX_comic_source_source_id",
                table: "comic_source",
                column: "source_id");

            migrationBuilder.CreateIndex(
                name: "IX_comic_tag_tag_id",
                table: "comic_tag",
                column: "tag_id");

            migrationBuilder.CreateIndex(
                name: "IX_engine_history_engine_id",
                table: "engine_history",
                column: "engine_id");

            migrationBuilder.CreateIndex(
                name: "IX_engine_history_overlay_box_id",
                table: "engine_history",
                column: "overlay_box_id");

            migrationBuilder.CreateIndex(
                name: "IX_overlay_box_page_id",
                table: "overlay_box",
                column: "page_id");

            migrationBuilder.CreateIndex(
                name: "IX_page_comic_id",
                table: "page",
                column: "comic_id");

            migrationBuilder.CreateIndex(
                name: "IX_tag_group_id",
                table: "tag",
                column: "group_id");

            migrationBuilder.AddForeignKey(
                name: "FK_comic_page_cover_page_id",
                table: "comic",
                column: "cover_page_id",
                principalTable: "page",
                principalColumn: "page_id",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_comic_page_cover_page_id",
                table: "comic");

            migrationBuilder.DropTable(
                name: "comic_creator");

            migrationBuilder.DropTable(
                name: "comic_source");

            migrationBuilder.DropTable(
                name: "comic_tag");

            migrationBuilder.DropTable(
                name: "download_source");

            migrationBuilder.DropTable(
                name: "engine_history");

            migrationBuilder.DropTable(
                name: "text_style");

            migrationBuilder.DropTable(
                name: "creator");

            migrationBuilder.DropTable(
                name: "source");

            migrationBuilder.DropTable(
                name: "tag");

            migrationBuilder.DropTable(
                name: "engine");

            migrationBuilder.DropTable(
                name: "overlay_box");

            migrationBuilder.DropTable(
                name: "tag_group");

            migrationBuilder.DropTable(
                name: "page");

            migrationBuilder.DropTable(
                name: "comic");
        }
    }
}
