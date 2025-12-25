import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../models/comic.dart';
import '../models/translation.dart';
import '../models/db/page_model.dart';
import '../models/db/comic_model.dart';
import '../models/db/tag_model.dart';
import '../models/db/creator_model.dart';
import '../models/db/source_model.dart';
import '../services/database_service.dart';
import '../repositories/page_repository.dart';
import '../repositories/overlay_box_repository.dart';
import '../repositories/comic_repository.dart';
import '../services/storage_service.dart';
import 'import_screen.dart';
import 'viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  final Comic comic;

  const GalleryScreen({super.key, required this.comic});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  int _crossAxisCount = 3;
  bool _showDetails = false;
  String _sortBy = 'name'; // 'name', 'date', 'translations'
  Map<String, int> _translationCounts = {};
  bool _isLoading = true;
  List<PageModel>? _pages;
  List<TagModel> _tags = [];
  List<CreatorModel> _creators = [];
  List<SourceModel> _sources = [];
  ComicModel? _comicModel;

  final DatabaseService _dbService = DatabaseService();
  PageRepository? _pageRepository;
  OverlayBoxRepository? _overlayBoxRepository;
  ComicRepository? _comicRepository;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      if (widget.comic.comicId == null) {
        debugPrint('GalleryScreen: No comicId, falling back to JSON loading');
        // Fall back to JSON loading if no comic ID
        await _loadTranslationCountsFromJson();
        setState(() {
          _isLoading = false;
        });
        return;
      }

      debugPrint('GalleryScreen: Initializing database for comicId: ${widget.comic.comicId}');
      await _dbService.initializeDatabase();
      _pageRepository = PageRepository(_dbService);
      _overlayBoxRepository = OverlayBoxRepository(_dbService);
      _comicRepository = ComicRepository(_dbService);
      
      debugPrint('GalleryScreen: Repositories initialized, loading metadata...');
      await _loadComicMetadata();
      await _loadTranslationCounts();
    } catch (e, stackTrace) {
      debugPrint('GalleryScreen: Error in _initializeDatabase: $e');
      debugPrint('GalleryScreen: Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadComicMetadata() async {
    if (widget.comic.comicId == null) {
      debugPrint('GalleryScreen: No comicId, using comicModel from widget');
      // Use comicModel if available
      if (widget.comic.comicModel != null) {
        setState(() {
          _comicModel = widget.comic.comicModel;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (_comicRepository == null) {
      debugPrint('GalleryScreen: ComicRepository is null, waiting...');
      // Wait a bit and try again
      await Future.delayed(const Duration(milliseconds: 100));
      if (_comicRepository == null) {
        debugPrint('GalleryScreen: ComicRepository still null after wait');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    try {
      debugPrint('GalleryScreen: Loading metadata for comicId: ${widget.comic.comicId}');
      
      // Load comic details
      final updatedComic = await _comicRepository!.getComicById(widget.comic.comicId!);
      debugPrint('GalleryScreen: Loaded comic: ${updatedComic?.title}');
      
      // Load tags, creators, sources
      final tagsData = await _comicRepository!.getComicTags(widget.comic.comicId!);
      debugPrint('GalleryScreen: Loaded ${tagsData.length} tags');
      if (tagsData.isNotEmpty) {
        debugPrint('GalleryScreen: First tag data: ${tagsData.first}');
      }
      
      final creatorsData = await _comicRepository!.getComicCreators(widget.comic.comicId!);
      debugPrint('GalleryScreen: Loaded ${creatorsData.length} creators');
      if (creatorsData.isNotEmpty) {
        debugPrint('GalleryScreen: First creator data: ${creatorsData.first}');
      }
      
      final sourcesData = await _comicRepository!.getComicSources(widget.comic.comicId!);
      debugPrint('GalleryScreen: Loaded ${sourcesData.length} sources');
      if (sourcesData.isNotEmpty) {
        debugPrint('GalleryScreen: First source data: ${sourcesData.first}');
      }

      setState(() {
        _comicModel = updatedComic;
        try {
          _tags = tagsData.map((data) {
            debugPrint('GalleryScreen: Mapping tag data: $data');
            return TagModel.fromMap(data);
          }).toList();
          _creators = creatorsData.map((data) {
            debugPrint('GalleryScreen: Mapping creator data: $data');
            return CreatorModel.fromMap(data);
          }).toList();
          _sources = sourcesData.map((data) {
            debugPrint('GalleryScreen: Mapping source data: $data');
            return SourceModel.fromMap(data);
          }).toList();
        } catch (e, stackTrace) {
          debugPrint('GalleryScreen: Error mapping metadata: $e');
          debugPrint('GalleryScreen: Stack trace: $stackTrace');
        }
        _isLoading = false;
      });
      
      debugPrint('GalleryScreen: Metadata loaded successfully');
    } catch (e, stackTrace) {
      debugPrint('GalleryScreen: Error loading comic metadata: $e');
      debugPrint('GalleryScreen: Stack trace: $stackTrace');
      // Fall back to comicModel if available
      if (widget.comic.comicModel != null) {
        setState(() {
          _comicModel = widget.comic.comicModel;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTranslationCounts() async {
    if (widget.comic.comicId == null || _pageRepository == null || _overlayBoxRepository == null) {
      await _loadTranslationCountsFromJson();
      return;
    }

    try {
      // Load pages for this comic
      _pages = await _pageRepository!.getPagesByComicId(widget.comic.comicId!);
      
      final Map<String, int> counts = {};
      
      // Load translation counts from database
      for (final page in _pages!) {
        if (page.pageId != null) {
          final overlayBoxes = await _overlayBoxRepository!.getOverlayBoxesByPageId(page.pageId!);
          final count = overlayBoxes.where((box) => 
            (box.translatedText ?? box.originalText ?? '').trim().isNotEmpty
          ).length;
          counts[page.storagePath] = count;
        } else {
          counts[page.storagePath] = 0;
        }
      }
      
      setState(() {
        _translationCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      // Fall back to JSON if database fails
      await _loadTranslationCountsFromJson();
    }
  }

  Future<void> _loadTranslationCountsFromJson() async {
    final Map<String, int> counts = {};
    
    for (final imageFile in widget.comic.images) {
      final jsonPath = '${path.withoutExtension(imageFile.path)}.json';
      final jsonFile = File(jsonPath);
      
      if (await jsonFile.exists()) {
        try {
          final jsonString = await jsonFile.readAsString();
          final List<dynamic> jsonList = json.decode(jsonString);
          final translations = jsonList.map((json) => Translation.fromJson(json)).toList();
          counts[imageFile.path] = translations.where((t) => t.text.trim().isNotEmpty).length;
        } catch (e) {
          counts[imageFile.path] = 0;
        }
      } else {
        counts[imageFile.path] = 0;
      }
    }
    
    setState(() {
      _translationCounts = counts;
      _isLoading = false;
    });
  }

  List<File> _getSortedImages() {
    final images = List<File>.from(widget.comic.images);
    
    switch (_sortBy) {
      case 'name':
        images.sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));
        break;
      case 'date':
        images.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        break;
      case 'translations':
        images.sort((a, b) {
          final countA = _translationCounts[a.path] ?? 0;
          final countB = _translationCounts[b.path] ?? 0;
          return countB.compareTo(countA);
        });
        break;
    }
    
    return images;
  }

  @override
  Widget build(BuildContext context) {
    final sortedImages = _getSortedImages();
    
    return Scaffold(
      body: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading...'),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadComicMetadata();
                  await _loadTranslationCounts();
                },
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with Title, Date, and Back button
                      _buildComicHeader(),
                      // Main Content: Cover + Info + Images
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Cover Image + Quick Actions
                          _buildLeftColumn(),
                          // Middle Column: Info Section
                          Expanded(
                            child: _buildInfoSection(),
                          ),
                        ],
                      ),
                      // Pictures Section
                      _buildPicturesSection(sortedImages),
                      // Related Galleries Footer (placeholder)
                      _buildRelatedGalleriesFooter(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildComicHeader() {
    final comic = _comicModel ?? widget.comic.comicModel;
    final displayTitle = comic?.title ?? widget.comic.name;
    final alternativeTitle = comic?.alternativeTitle;
    final updatedAt = comic?.updatedAt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[900]
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayTitle,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (alternativeTitle != null && alternativeTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    alternativeTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                        ),
                  ),
                ],
              ],
            ),
          ),
          if (updatedAt != null) ...[
            const SizedBox(width: 16),
            Text(
              _formatDate(updatedAt),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
          // Menu button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog();
              } else if (value == 'delete') {
                _showDeleteConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20),
                    SizedBox(width: 8),
                    Text('Edit Info'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.grey[50],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Sort button
          PopupMenuButton<String>(
            tooltip: 'Sort by',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      size: 18,
                      color: _sortBy == 'name' ? Theme.of(context).primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Name'),
                    if (_sortBy == 'name') ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: _sortBy == 'date' ? Theme.of(context).primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Modified Date'),
                    if (_sortBy == 'date') ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'translations',
                child: Row(
                  children: [
                    Icon(
                      Icons.translate,
                      size: 18,
                      color: _sortBy == 'translations' ? Theme.of(context).primaryColor : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Translations'),
                    if (_sortBy == 'translations') ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 18),
                  const SizedBox(width: 6),
                  const Text('Sort'),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // View toggle button
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _showDetails = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: !_showDetails ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomLeft: Radius.circular(6),
                      ),
                    ),
                    child: Icon(
                      Icons.grid_view,
                      size: 18,
                      color: !_showDetails ? Theme.of(context).primaryColor : Colors.grey[600],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _showDetails = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _showDetails ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      ),
                    ),
                    child: Icon(
                      Icons.view_list,
                      size: 18,
                      color: _showDetails ? Theme.of(context).primaryColor : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Grid size button
          PopupMenuButton<int>(
            tooltip: 'Grid size',
            onSelected: (value) {
              setState(() {
                _crossAxisCount = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    const Icon(Icons.view_module, size: 18),
                    const SizedBox(width: 8),
                    const Text('Large (2 columns)'),
                    if (_crossAxisCount == 2) ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 3,
                child: Row(
                  children: [
                    const Icon(Icons.grid_view, size: 18),
                    const SizedBox(width: 8),
                    const Text('Medium (3 columns)'),
                    if (_crossAxisCount == 3) ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 4,
                child: Row(
                  children: [
                    const Icon(Icons.apps, size: 18),
                    const SizedBox(width: 8),
                    const Text('Small (4 columns)'),
                    if (_crossAxisCount == 4) ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 5,
                child: Row(
                  children: [
                    const Icon(Icons.view_comfy, size: 18),
                    const SizedBox(width: 8),
                    const Text('Compact (5 columns)'),
                    if (_crossAxisCount == 5) ...[
                      const Spacer(),
                      Icon(Icons.check, size: 18, color: Theme.of(context).primaryColor),
                    ],
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Grid: $_crossAxisCount'),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Page count
          Text(
            '${widget.comic.images.length} pages',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    final comic = _comicModel ?? widget.comic.comicModel;
    final coverImagePath = comic?.coverImagePath;
    File? coverImage;

    // Try to get cover image
    if (coverImagePath != null) {
      coverImage = File(coverImagePath);
      if (!coverImage.existsSync()) {
        coverImage = null;
      }
    }
    
    // Fallback to first image
    if (coverImage == null && widget.comic.images.isNotEmpty) {
      coverImage = widget.comic.images.first;
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Cover Image
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: coverImage != null && coverImage.existsSync()
                  ? Image.file(
                      coverImage,
                      width: 218,
                      height: 300,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 218,
                      height: 300,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image, size: 48, color: Colors.grey),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // Quick Actions
          Container(
            width: 218,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (widget.comic.images.isNotEmpty) {
                        _openViewer(context, widget.comic.images.first);
                      }
                    },
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Read Now'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Add to favorites or bookmark
                    },
                    icon: const Icon(Icons.bookmark_border, size: 20),
                    label: const Text('Bookmark'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    final comic = _comicModel ?? widget.comic.comicModel;
    final description = comic?.description;
    final status = comic?.status ?? 'active';
    final rating = comic?.rating;
    final pageCount = widget.comic.images.length;
    final date = comic?.createdAt ?? DateTime.now();

    // Get creators grouped by role
    final creatorsByRole = <String, List<CreatorModel>>{};
    for (final creator in _creators) {
      final role = creator.role ?? 'Creator';
      creatorsByRole.putIfAbsent(role, () => []).add(creator);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Description (Placed at top for better context)
          if (description != null && description.isNotEmpty) ...[
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.9),
                  ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Stats Row (Icon + Text style)
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              // Pages
              _buildIconStat(Icons.copy, '$pageCount pages'),
              
              // Status
              _buildIconStat(
                status == 'active' ? Icons.fiber_manual_record : Icons.check_circle, 
                status.toUpperCase(),
                color: status == 'active' ? Colors.green : Colors.grey,
              ),

              // Rating
              if (rating != null)
                _buildIconStat(Icons.star, '$rating/10', color: Colors.amber),

              // Date
              _buildIconStat(Icons.calendar_today, _formatDate(date).split(',')[0]), // Show date only part
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),

          // 3. Metadata (Creators, Sources, etc.)
          // Creators
          ...creatorsByRole.entries.map((entry) {
            final role = entry.key;
            final creators = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      role,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      children: creators.map((c) => InkWell(
                        onTap: () {
                           final url = c.websiteUrl ?? c.socialLink;
                           if (url != null && url.isNotEmpty) {
                             _launchUrl(url);
                           }
                        },
                        child: Text(
                          c.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: (c.websiteUrl != null || c.socialLink != null) ? Colors.blueAccent : Theme.of(context).textTheme.bodyMedium?.color, 
                            decoration: (c.websiteUrl != null || c.socialLink != null) ? TextDecoration.underline : null,
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Sources
          if (_sources.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Source',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _sources.map((s) {
                        String display = 'Unknown';
                        if (s.platform != null) display = s.platform!;
                        else if (s.sourceUrl != null) display = 'Link';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: InkWell(
                            onTap: s.sourceUrl != null ? () {
                              _launchUrl(s.sourceUrl!);
                            } : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  display,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: s.sourceUrl != null ? Colors.blueAccent : Theme.of(context).textTheme.bodyMedium?.color,
                                    decoration: s.sourceUrl != null ? TextDecoration.underline : null,
                                  ),
                                ),
                                if (s.sourceUrl != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.open_in_new, size: 10, color: Colors.blueAccent),
                                ]
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

          // 4. Tags (Only if available)
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1), // Subtle background
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    tag.name,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          
          // 5. Progress Bar
          const SizedBox(height: 16),
          Divider(color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 12),
          _buildStatsBar(),
        ],
      ),
    );
  }

  Widget _buildIconStat(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: color ?? Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildPicturesSection(List<File> sortedImages) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pictures',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Row(
                children: [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort by',
                    onSelected: (value) {
                      setState(() {
                        _sortBy = value;
                      });
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'name',
                        child: Row(
                          children: [
                            Icon(
                              Icons.sort_by_alpha,
                              color: _sortBy == 'name' ? Theme.of(context).primaryColor : null,
                            ),
                            const SizedBox(width: 8),
                            const Text('Name'),
                            if (_sortBy == 'name') ...[
                              const Spacer(),
                              Icon(Icons.check, color: Theme.of(context).primaryColor),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'date',
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: _sortBy == 'date' ? Theme.of(context).primaryColor : null,
                            ),
                            const SizedBox(width: 8),
                            const Text('Modified Date'),
                            if (_sortBy == 'date') ...[
                              const Spacer(),
                              Icon(Icons.check, color: Theme.of(context).primaryColor),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'translations',
                        child: Row(
                          children: [
                            Icon(
                              Icons.translate,
                              color: _sortBy == 'translations' ? Theme.of(context).primaryColor : null,
                            ),
                            const SizedBox(width: 8),
                            const Text('Translations'),
                            if (_sortBy == 'translations') ...[
                              const Spacer(),
                              Icon(Icons.check, color: Theme.of(context).primaryColor),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.grid_view),
                    tooltip: 'Grid size',
                    onSelected: (value) {
                      setState(() {
                        _crossAxisCount = value;
                      });
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 2,
                        child: Row(
                          children: [
                            const Icon(Icons.view_module),
                            const SizedBox(width: 8),
                            const Text('Large (2 columns)'),
                            if (_crossAxisCount == 2) ...[
                              const Spacer(),
                              Icon(Icons.check, color: Theme.of(context).primaryColor),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 3,
                        child: Row(
                          children: [
                            const Icon(Icons.grid_view),
                            const SizedBox(width: 8),
                            const Text('Medium (3 columns)'),
                            if (_crossAxisCount == 3) ...[
                              const Spacer(),
                              Icon(Icons.check, color: Theme.of(context).primaryColor),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 4,
                        child: Row(
                          children: [
                            const Icon(Icons.apps),
                            const SizedBox(width: 8),
                            const Text('Small (4 columns)'),
                            if (_crossAxisCount == 4) ...[
                              const Spacer(),
                              Icon(Icons.check, color: Theme.of(context).primaryColor),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 5,
                        child: Row(
                          children: [
                            const Icon(Icons.view_comfy),
                            const SizedBox(width: 8),
                            const Text('Compact (5 columns)'),
                            if (_crossAxisCount == 5) ...[
                              const Spacer(),
                              Icon(Icons.check, color: Theme.of(context).primaryColor),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _crossAxisCount,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 0.7,
              ),
              itemCount: sortedImages.length,
              itemBuilder: (context, index) {
                final imageFile = sortedImages[index];
                final translationCount = _translationCounts[imageFile.path] ?? 0;

                return KeyedSubtree(
                  key: ValueKey(imageFile.path),
                  child: _buildImageCard(imageFile, translationCount, index + 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedGalleriesFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
      ),
      child: Text(
        'Related Galleries',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildImageCard(File imageFile, int translationCount, int pageNumber) {
  bool isHovered = false;
  final fileName = path.basename(imageFile.path);

  return StatefulBuilder(
    builder: (context, setState) {
      return MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: Card(
          elevation: isHovered ? 4 : 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openViewer(context, imageFile),
            child: Stack(
              children: [
                // Image
                Positioned.fill(
                  child: Hero(
                    tag: imageFile.path,
                    child: Image.file(
                      imageFile,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Page number
                Positioned(
                  top: 4,
                  left: 4,
                  child: _buildPageBadge(pageNumber),
                ),

                // Translation count
                if (translationCount > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _buildTranslationBadge(translationCount),
                  ),

                // Hover filename strip
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black54,
                          ],
                        ),
                      ),
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black,
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildPageBadge(int pageNumber) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.7),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      pageNumber.toString(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _buildTranslationBadge(int translationCount) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.green.withOpacity(0.9),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.translate, size: 12, color: Colors.white),
        const SizedBox(width: 2),
        Text(
          translationCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
  Widget _buildImageDetails(File imageFile, int translationCount) {
    final fileName = path.basename(imageFile.path);
    final fileStat = imageFile.statSync();
    final fileSize = _formatFileSize(fileStat.size);
    final lastModified = _formatDate(fileStat.modified);

    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                translationCount > 0 ? Icons.check_circle : Icons.pending,
                size: 12,
                color: translationCount > 0 ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                translationCount > 0 
                    ? '$translationCount translations'
                    : 'No translations',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.storage, size: 10, color: Colors.grey[500]),
              const SizedBox(width: 2),
              Text(
                fileSize,
                style: TextStyle(fontSize: 9, color: Colors.grey[500]),
              ),
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 10, color: Colors.grey[500]),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  lastModified,
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    final totalPages = widget.comic.images.length;
    final translatedPages = _translationCounts.values.where((count) => count > 0).length;
    final totalTranslations = _translationCounts.values.fold(0, (sum, count) => sum + count);
    final progress = totalPages > 0 ? translatedPages / totalPages : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_stories, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              'Progress: $translatedPages/$totalPages pages',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            Text(
              ' (${(progress * 100).toStringAsFixed(1)}%)',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.translate,
                    size: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$totalTranslations translations',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
            progress < 0.3 ? Colors.red : progress < 0.7 ? Colors.orange : Colors.green,
          ),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    // Format: "19 Jun 2025, 00:21"
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    
    return '$day $month $year, $hour:$minute';
  }

  void _openViewer(BuildContext context, File imageFile) {
    final sortedImages = _getSortedImages();
    final initialIndex = sortedImages.indexOf(imageFile);
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            ViewerScreen(
              imageFiles: sortedImages, 
              initialIndex: initialIndex >= 0 ? initialIndex : 0,
              pages: _pages, // Pass pages if available
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  void _showEditDialog() {
    final comic = _comicModel ?? widget.comic.comicModel;
    if (comic == null || comic.comicId == null) return;

    // Navigate to ImportScreen in edit mode
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImportScreen(comicId: comic.comicId!),
      ),
    ).then((result) {
      if (result == true) {
        // Reload comic metadata after edit
        _loadComicMetadata();
        // Don't pop - stay on GalleryScreen to see updated data
      }
    });
  }

  void _showDeleteConfirmation() {
    final comic = _comicModel ?? widget.comic.comicModel;
    if (comic == null || comic.comicId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comic'),
        content: Text('Are you sure you want to delete "${comic.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final comicId = comic.comicId!;
                await _comicRepository!.deleteComic(comicId);
                
                // Also delete from storage
                try {
                  final storageService = StorageService();
                  await storageService.deleteComicStorage(comicId);
                } catch (e) {
                  debugPrint('Error deleting comic storage: $e');
                }
                
                if (mounted) {
                  Navigator.of(context).pop(); // Close confirmation dialog
                  Navigator.of(context).pop(true); // Go back to home screen with refresh flag
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comic deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting comic: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}