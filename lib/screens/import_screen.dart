import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/db/comic_model.dart';
import '../models/db/page_model.dart';
import '../models/db/source_model.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/metadata_extractor.dart';
import '../repositories/comic_repository.dart';
import '../repositories/page_repository.dart';
import '../repositories/source_repository.dart';
import '../repositories/tag_repository.dart';
import '../repositories/creator_repository.dart';
import '../widgets/tag_selector.dart';
import '../widgets/creator_selector.dart';

class ImportScreen extends StatefulWidget {
  final int? comicId; // If provided, edit mode

  const ImportScreen({super.key, this.comicId});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _altTitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  final MetadataExtractor _metadataExtractor = MetadataExtractor();
  
  late ComicRepository _comicRepository;
  late PageRepository _pageRepository;
  late SourceRepository _sourceRepository;
  late TagRepository _tagRepository;
  late CreatorRepository _creatorRepository;

  // Selected raw files from file system (not imported yet)
  List<File> _selectedFiles = [];
  bool _isSaving = false;
  double _saveProgress = 0.0;
  String _saveStatus = '';

  // Form fields
  String _status = 'active';
  int? _rating;
  List<int> _selectedTagIds = [];
  List<int> _selectedCreatorIds = [];
  
  // Cover selection (index in _selectedFiles list)
  int _selectedCoverIndex = 0;
  
  // Source fields
  final _platformController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  final _authorHandleController = TextEditingController();
  final _postIdController = TextEditingController();
  final _sourceDescriptionController = TextEditingController();
  bool _isPrimarySource = false;

  bool get _isEditMode => widget.comicId != null;
  List<PageModel> _existingPages = [];
  bool _isLoading = false;
  bool _repositoriesInitialized = false;
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
  }

  Future<void> _initializeRepositories() async {
    await _dbService.initializeDatabase();
    setState(() {
      _comicRepository = ComicRepository(_dbService);
      _pageRepository = PageRepository(_dbService);
      _sourceRepository = SourceRepository(_dbService);
      _tagRepository = TagRepository(_dbService);
      _creatorRepository = CreatorRepository(_dbService);
      _repositoriesInitialized = true;
    });
    
    // Load comic data after repositories are initialized
    if (_isEditMode && !_dataLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_dataLoaded) {
          _loadComicData();
        }
      });
    }
  }

  Future<void> _loadComicData() async {
    if (widget.comicId == null || !_repositoriesInitialized) return;

    setState(() => _isLoading = true);

    try {
      // Load comic
      final comic = await _comicRepository.getComicById(widget.comicId!);
      if (comic == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comic not found')),
          );
        }
        return;
      }

      // Load pages
      _existingPages = await _pageRepository.getPagesByComicId(widget.comicId!);
      
      // Load tags, creators, sources
      final tagsData = await _comicRepository.getComicTags(widget.comicId!);
      final creatorsData = await _comicRepository.getComicCreators(widget.comicId!);
      final sourcesData = await _comicRepository.getComicSources(widget.comicId!);

      debugPrint('Loaded sources: ${sourcesData.length}');
      if (sourcesData.isNotEmpty) {
        debugPrint('First source data: ${sourcesData.first}');
      }

      // Load existing pages as files
      final existingFiles = _existingPages
          .map((p) => File(p.storagePath))
          .where((f) => f.existsSync())
          .toList();
      
      // Populate all form fields in setState
      setState(() {
        // Basic info
        _titleController.text = comic.title;
        _altTitleController.text = comic.alternativeTitle ?? '';
        _descriptionController.text = comic.description ?? '';
        _status = comic.status ?? 'active';
        _rating = comic.rating;
        
        // Tags and creators
        _selectedTagIds = tagsData.map((t) => t['tag_id'] as int).toList();
        _selectedCreatorIds = creatorsData.map((c) => c['creator_id'] as int).toList();
        
        // Files
        _selectedFiles = existingFiles;
        _selectedCoverIndex = comic.coverPageId != null
            ? _existingPages.indexWhere((p) => p.pageId == comic.coverPageId) 
            : 0;
        if (_selectedCoverIndex < 0) _selectedCoverIndex = 0;

        // Source data (use first source if exists)
        if (sourcesData.isNotEmpty) {
          final source = sourcesData.first;
          _platformController.text = source['platform']?.toString() ?? '';
          _sourceUrlController.text = source['source_url']?.toString() ?? '';
          _authorHandleController.text = source['author_handle']?.toString() ?? '';
          _postIdController.text = source['post_id']?.toString() ?? '';
          _sourceDescriptionController.text = source['description']?.toString() ?? '';
          _isPrimarySource = source['is_primary'] as bool? ?? false;
        } else {
          // Clear source fields if no source exists
          _platformController.clear();
          _sourceUrlController.clear();
          _authorHandleController.clear();
          _postIdController.clear();
          _sourceDescriptionController.clear();
          _isPrimarySource = false;
        }
        
        _dataLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading comic data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading comic: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _altTitleController.dispose();
    _descriptionController.dispose();
    _platformController.dispose();
    _sourceUrlController.dispose();
    _authorHandleController.dispose();
    _postIdController.dispose();
    _sourceDescriptionController.dispose();
    _dbService.dispose();
    super.dispose();
  }

  Future<void> _selectFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
    );

    if (result != null) {
      final files = result.paths
          .where((path) => path != null)
          .map((path) => File(path!))
          .toList();
          
      // Sort files by name natural order
      files.sort((a, b) => a.path.compareTo(b.path));

      setState(() {
        _selectedFiles = files;
        _selectedCoverIndex = 0; // Default to first image
        
        // Auto-fill title from folder name if empty
        if (_titleController.text.isEmpty && files.isNotEmpty) {
          _titleController.text = files.first.parent.path.split(Platform.pathSeparator).last;
        }
      });
    }
  }

  Future<void> _selectDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    
    if (result != null) {
      final dir = Directory(result);
      final files = <File>[];
      
      try {
        await for (final entity in dir.list(recursive: false)) { // recursive false to keep it simple for now, or true if needed
          if (entity is File) {
            final ext = entity.path.split('.').last.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
              files.add(entity);
            }
          }
        }
      } catch (e) {
        debugPrint('Error listing files: $e');
      }
      
      // Sort files
      files.sort((a, b) => a.path.compareTo(b.path));
      
      setState(() {
        _selectedFiles = files;
        _selectedCoverIndex = 0;
        
        // Auto-fill title from folder name
        if (_titleController.text.isEmpty) {
          _titleController.text = dir.path.split(Platform.pathSeparator).last;
        }
      });

      if (files.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No supported image files found in selected folder')),
        );
      }
    }
  }

  Future<void> _saveComic() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFiles.isEmpty && !_isEditMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select files first')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _saveProgress = 0.0;
      _saveStatus = _isEditMode ? 'Updating...' : 'Initializing...';
    });

    try {
      final now = DateTime.now();
      final comicId = _isEditMode ? widget.comicId! : null;
      final comicPath = comicId != null 
          ? await _storageService.getComicStoragePath(comicId)
          : null;
      
      // 1. Create or Update Comic Record
      ComicModel tempComic;
      int finalComicId;
      if (_isEditMode) {
        // Update existing comic
        final existingComic = await _comicRepository.getComicById(comicId!);
        if (existingComic == null) {
          throw Exception('Comic not found');
        }
        tempComic = existingComic.copyWith(
          title: _titleController.text.trim(),
          alternativeTitle: _altTitleController.text.trim().isEmpty ? null : _altTitleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          status: _status,
          rating: _rating,
          updatedAt: now,
        );
        await _comicRepository.updateComic(tempComic);
        finalComicId = comicId!;
      } else {
        // Create new comic
        tempComic = ComicModel(
          title: _titleController.text.trim(),
          alternativeTitle: _altTitleController.text.trim().isEmpty ? null : _altTitleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          managedPath: '', // Will update later
          status: _status,
          rating: _rating,
          createdAt: now,
          updatedAt: now,
        );
        final newComicId = await _comicRepository.createComic(tempComic);
        final newComicPath = await _storageService.getComicStoragePath(newComicId);
        // Update with actual path
        tempComic = tempComic.copyWith(comicId: newComicId, managedPath: newComicPath);
        await _comicRepository.updateComic(tempComic);
        finalComicId = newComicId;
      }

      // 2. Process & Copy Files (only if new files are selected)
      final pages = <PageModel>[];
      String? coverImagePath;
      
      // Check if files are new (not already imported)
      final newFiles = _selectedFiles.where((file) {
        // Check if file is already in existing pages
        if (_isEditMode) {
          return !_existingPages.any((p) => p.storagePath == file.path);
        }
        return true;
      }).toList();

      // Process new files
      for (int i = 0; i < newFiles.length; i++) {
        final file = newFiles[i];
        final originalIndex = _selectedFiles.indexOf(file);
        
        setState(() {
          _saveProgress = (i / (newFiles.length + 1));
          _saveStatus = _isEditMode 
              ? 'Adding ${i + 1}/${newFiles.length} new files...'
              : 'Importing ${i + 1}/${newFiles.length}';
        });

        // Copy file
        final importedPath = await _storageService.importFile(file, finalComicId);
        
        // Extract metadata
        final metadata = await _metadataExtractor.extractMetadata(File(importedPath));
        
        // Determine page number
        final pageNumber = _isEditMode 
            ? (_existingPages.length + i + 1)
            : (i + 1);
        
        // Create page model
        final page = PageModel(
          comicId: finalComicId,
          pageNumber: pageNumber,
          storagePath: importedPath,
          fileName: file.path.split(Platform.pathSeparator).last,
          fileExtension: metadata.fileExtension,
          fileSizeBytes: metadata.fileSizeBytes,
          width: metadata.width,
          height: metadata.height,
          dpi: metadata.dpi,
          colorProfile: metadata.colorProfile,
          imageHash: metadata.imageHash,
          createdAt: now,
        );

        final pageId = await _pageRepository.createPage(page);
        pages.add(page.copyWith(pageId: pageId));

        // Generate thumbnail for the selected cover
        if (originalIndex == _selectedCoverIndex) {
          coverImagePath = importedPath;
          
          // Generate thumbnail for cover (optional optimization)
          try {
            final thumbnailBytes = await _metadataExtractor.generateThumbnail(File(importedPath));
            if (thumbnailBytes != null) {
              final thumbnailPath = importedPath.replaceAll(RegExp(r'\.[^.]+$'), '_thumb.jpg');
              await File(thumbnailPath).writeAsBytes(thumbnailBytes);
              // Update page with thumbnail path
              await _pageRepository.updatePage(page.copyWith(pageId: pageId, thumbnailPath: thumbnailPath));
            }
          } catch (e) {
            debugPrint('Thumbnail generation failed: $e');
          }
        }
      }
      
      // If edit mode and cover hasn't changed, use existing cover
      if (_isEditMode && coverImagePath == null && _existingPages.isNotEmpty) {
        final existingComic = await _comicRepository.getComicById(finalComicId);
        if (existingComic?.coverImagePath != null) {
          coverImagePath = existingComic!.coverImagePath;
        }
      }
      
      // Get all pages for cover page ID
      final allPages = _isEditMode 
          ? [..._existingPages, ...pages]
          : pages;

      // 3. Update Comic with Cover & Path
      int? coverPageId;
      if (_selectedCoverIndex < allPages.length) {
        coverPageId = allPages[_selectedCoverIndex].pageId;
      }
      
      final finalManagedPath = comicPath ?? tempComic.managedPath ?? '';
      await _comicRepository.updateComic(
        tempComic.copyWith(
          comicId: finalComicId,
          managedPath: finalManagedPath.isEmpty ? null : finalManagedPath,
          coverImagePath: coverImagePath,
          coverPageId: coverPageId,
        ),
      );

      // 4. Link Metadata (Tags, Creators, Sources)
      setState(() => _saveStatus = 'Linking metadata...');
      
      // Tags: Unlink all, then link selected
      if (_isEditMode) {
        final existingTags = await _comicRepository.getComicTags(finalComicId);
        debugPrint('ImportScreen: Unlinking ${existingTags.length} existing tags');
        for (final tag in existingTags) {
          await _comicRepository.unlinkTag(finalComicId, tag['tag_id'] as int);
        }
      }
      debugPrint('ImportScreen: Linking ${_selectedTagIds.length} tags');
      for (final tagId in _selectedTagIds) {
        try {
          await _comicRepository.linkTag(finalComicId, tagId);
        } catch (e) {
          debugPrint('ImportScreen: Error linking tag $tagId: $e');
          // Ignore if already linked
        }
      }

      // Creators: Unlink all, then link selected
      if (_isEditMode) {
        final existingCreators = await _comicRepository.getComicCreators(finalComicId);
        debugPrint('ImportScreen: Unlinking ${existingCreators.length} existing creators');
        for (final creator in existingCreators) {
          await _comicRepository.unlinkCreator(finalComicId, creator['creator_id'] as int);
        }
      }
      debugPrint('ImportScreen: Linking ${_selectedCreatorIds.length} creators');
      for (final creatorId in _selectedCreatorIds) {
        try {
          await _comicRepository.linkCreator(finalComicId, creatorId);
        } catch (e) {
          debugPrint('ImportScreen: Error linking creator $creatorId: $e');
          // Ignore if already linked
        }
      }

      // Sources: Update existing or create new
      if (_isEditMode) {
        final existingSources = await _comicRepository.getComicSources(finalComicId);
        // Update first source if exists and has data, else create new if has data, else do nothing
        if (existingSources.isNotEmpty) {
          final sourceId = existingSources.first['source_id'] as int;
          final existingSourceData = existingSources.first;
          
          // Always update existing source, even if fields are empty (to preserve it)
          final updatedSource = SourceModel.fromMap({
            ...existingSourceData,
            'platform': _platformController.text.trim().isEmpty ? null : _platformController.text.trim(),
            'source_url': _sourceUrlController.text.trim().isEmpty ? null : _sourceUrlController.text.trim(),
            'author_handle': _authorHandleController.text.trim().isEmpty ? null : _authorHandleController.text.trim(),
            'post_id': _postIdController.text.trim().isEmpty ? null : _postIdController.text.trim(),
            'description': _sourceDescriptionController.text.trim().isEmpty ? null : _sourceDescriptionController.text.trim(),
            'is_primary': _isPrimarySource,
          });
          await _sourceRepository.updateSource(updatedSource);
        } else if (_platformController.text.trim().isNotEmpty || 
                   _sourceUrlController.text.trim().isNotEmpty ||
                   _authorHandleController.text.trim().isNotEmpty ||
                   _postIdController.text.trim().isNotEmpty) {
          // Create new source if none exists and has at least one field
          final source = SourceModel(
            platform: _platformController.text.trim().isEmpty ? null : _platformController.text.trim(),
            sourceUrl: _sourceUrlController.text.trim().isEmpty ? null : _sourceUrlController.text.trim(),
            authorHandle: _authorHandleController.text.trim().isEmpty ? null : _authorHandleController.text.trim(),
            postId: _postIdController.text.trim().isEmpty ? null : _postIdController.text.trim(),
            description: _sourceDescriptionController.text.trim().isEmpty ? null : _sourceDescriptionController.text.trim(),
            discoveredAt: now,
            isPrimary: _isPrimarySource,
          );
          final sourceId = await _sourceRepository.createSource(source);
          await _comicRepository.linkSource(finalComicId, sourceId);
        }
      } else {
        // Create mode: only create if has data
        if (_platformController.text.trim().isNotEmpty || 
            _sourceUrlController.text.trim().isNotEmpty ||
            _authorHandleController.text.trim().isNotEmpty ||
            _postIdController.text.trim().isNotEmpty) {
          final source = SourceModel(
            platform: _platformController.text.trim().isEmpty ? null : _platformController.text.trim(),
            sourceUrl: _sourceUrlController.text.trim().isEmpty ? null : _sourceUrlController.text.trim(),
            authorHandle: _authorHandleController.text.trim().isEmpty ? null : _authorHandleController.text.trim(),
            postId: _postIdController.text.trim().isEmpty ? null : _postIdController.text.trim(),
            description: _sourceDescriptionController.text.trim().isEmpty ? null : _sourceDescriptionController.text.trim(),
            discoveredAt: now,
            isPrimary: _isPrimarySource,
          );
          final sourceId = await _sourceRepository.createSource(source);
          await _comicRepository.linkSource(finalComicId, sourceId);
        }
      }

      // Done
      setState(() {
        _isSaving = false;
        _saveStatus = 'Success!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditMode ? 'Comic updated successfully' : 'Comic imported successfully')),
        );
        Navigator.pop(context, true);
      }

    } catch (e) {
      setState(() {
        _isSaving = false;
        _saveStatus = 'Error';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving comic: $e')),
        );
      }
      // Optional: Cleanup if failed (delete folder & DB record)
    }
  }

  @override
  Widget build(BuildContext context) {
    // If saving, show full screen progress to prevent interaction
    if (_isSaving) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _saveStatus,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('${(_saveProgress * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Comic'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton.icon(
              icon: const Icon(Icons.save),
              label: Text(_isEditMode ? 'Save Changes' : 'Save & Import'),
              onPressed: (_selectedFiles.isEmpty && !_isEditMode) ? null : _saveComic,
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Panel: Files & Preview
          SizedBox(
            width: 400,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Theme.of(context).dividerColor),
                ),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
              ),
              child: Column(
                children: [
                  _buildFileSelectionHeader(),
                  Expanded(
                    child: _selectedFiles.isEmpty
                        ? _buildEmptyState()
                        : _buildFilePreviewGrid(),
                  ),
                ],
              ),
            ),
          ),
          // Right Panel: Metadata Form
          Expanded(
            child: (_selectedFiles.isEmpty && !_isEditMode)
                ? const Center(
                    child: Text(
                      'Select files to begin editing metadata',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : !_repositoriesInitialized
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('Basic Information'),
                              const SizedBox(height: 16),
                              _buildBasicInfoFields(),
                              const SizedBox(height: 32),
                              
                              _buildSectionTitle('Metadata'),
                              const SizedBox(height: 16),
                              _buildMetadataFields(),
                              const SizedBox(height: 32),
                              
                              _buildSectionTitle('Source Information'),
                              const SizedBox(height: 16),
                              _buildSourceFields(),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // In edit mode, don't show empty state since files are already loaded
    if (_isEditMode) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No files selected',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _selectFiles,
                icon: const Icon(Icons.file_copy),
                label: const Text('Select Files'),
              ),
              ElevatedButton.icon(
                onPressed: _selectDirectory,
                icon: const Icon(Icons.create_new_folder),
                label: const Text('Select Folder'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileSelectionHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedFiles.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedFiles.length} files selected',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cover: Image ${_selectedCoverIndex + 1}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reselect',
                  onPressed: () {
                    setState(() {
                      _selectedFiles.clear();
                      _titleController.clear();
                    });
                  },
                ),
              ],
            )
          else
             const Text('Files', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFilePreviewGrid() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pages (${_selectedFiles.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: const Icon(Icons.sort_by_alpha, size: 16),
                label: const Text('Sort by Name'),
                onPressed: () {
                  setState(() {
                    final coverFile = _selectedFiles[_selectedCoverIndex];
                    _selectedFiles.sort((a, b) => a.path.compareTo(b.path));
                    _selectedCoverIndex = _selectedFiles.indexOf(coverFile);
                  });
                },
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.7,
            ),
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              final isCover = index == _selectedCoverIndex;
              
              return DragTarget<int>(
                onWillAccept: (data) => data != null && data != index,
                onAccept: (fromIndex) {
                  setState(() {
                    final coverFile = _selectedFiles[_selectedCoverIndex];
                    final item = _selectedFiles.removeAt(fromIndex);
                    _selectedFiles.insert(index, item);
                    _selectedCoverIndex = _selectedFiles.indexOf(coverFile);
                  });
                },
                builder: (context, candidateData, rejectedData) {
                  final isTarget = candidateData.isNotEmpty;
                  
                  return LongPressDraggable<int>(
                    data: index,
                    feedback: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 120,
                        height: 170,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          image: DecorationImage(
                            image: FileImage(file),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: _buildGridItem(file, index, isCover),
                    ),
                    child: Stack(
                      children: [
                        _buildGridItem(file, index, isCover),
                        if (isTarget)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Long press and drag to reorder. Click to select Cover.',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildGridItem(File file, int index, bool isCover) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCoverIndex = index;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isCover 
                ? Colors.lightGreen 
                : Colors.transparent,
            width: 4,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.broken_image, size: 20));
                },
              ),
            ),
            if (isCover)
              Container(
                color: Colors.lightGreen.withOpacity(0.2),
              ),
            if (isCover)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.lightGreen,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Page ${index + 1}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 24,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoFields() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                  helperText: 'Required',
                ),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'on_hold', child: Text('On Hold')),
                  DropdownMenuItem(value: 'dropped', child: Text('Dropped')),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'active'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _altTitleController,
          decoration: const InputDecoration(
            labelText: 'Alternative Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Rating:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Slider(
                value: (_rating ?? 0).toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '${_rating ?? 0}',
                onChanged: (value) => setState(() => _rating = value.round()),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_rating ?? 0}/10',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetadataFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TagSelector(
          tagRepository: _tagRepository,
          selectedTagIds: _selectedTagIds,
          onSelectionChanged: (ids) => setState(() => _selectedTagIds = ids),
        ),
        const SizedBox(height: 24),
        CreatorSelector(
          creatorRepository: _creatorRepository,
          selectedCreatorIds: _selectedCreatorIds,
          onSelectionChanged: (ids) => setState(() => _selectedCreatorIds = ids),
        ),
      ],
    );
  }

  Widget _buildSourceFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _platformController,
                decoration: const InputDecoration(
                  labelText: 'Platform',
                  hintText: 'e.g. Pixiv, Twitter',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _authorHandleController,
                decoration: const InputDecoration(
                  labelText: 'Author Handle',
                  hintText: '@username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _sourceUrlController,
          decoration: const InputDecoration(
            labelText: 'Source URL',
            hintText: 'https://...',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('Primary Source'),
          subtitle: const Text('Mark this as the main source for this comic'),
          value: _isPrimarySource,
          onChanged: (value) => setState(() => _isPrimarySource = value ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }
}
