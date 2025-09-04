import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../models/comic.dart';
import '../models/translation.dart';
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

  @override
  void initState() {
    super.initState();
    _loadTranslationCounts();
  }

  Future<void> _loadTranslationCounts() async {
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.comic.name),
            Text(
              '${widget.comic.images.length} pages',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
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
          IconButton(
            icon: Icon(_showDetails ? Icons.view_module : Icons.view_list),
            onPressed: () {
              setState(() {
                _showDetails = !_showDetails;
              });
            },
            tooltip: _showDetails ? 'Hide details' : 'Show details',
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading translation data...'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTranslationCounts,
              child: GridView.builder(
                padding: const EdgeInsets.all(12.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _crossAxisCount,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,
                  childAspectRatio: _showDetails ? 0.75 : 1.0,
                ),
                itemCount: sortedImages.length,
                itemBuilder: (context, index) {
                  final imageFile = sortedImages[index];
                  final translationCount = _translationCounts[imageFile.path] ?? 0;
                  
                  return _buildImageCard(imageFile, translationCount, index + 1);
                },
              ),
            ),
      bottomNavigationBar: _buildStatsBar(),
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_stories, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Progress: $translatedPages/$totalPages pages',
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                    ),
                    Text(
                      ' (${(progress * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress < 0.3 ? Colors.red : progress < 0.7 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
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
                  totalTranslations.toString(),
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
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${date.day}/${date.month}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }

  void _openViewer(BuildContext context, File imageFile) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
            ViewerScreen(imageFile: imageFile),
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
}