import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import '../models/translation.dart';
import '../models/db/comic_model.dart';
import '../models/db/page_model.dart';
import '../models/db/overlay_box_model.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/metadata_extractor.dart';
import '../repositories/comic_repository.dart';
import '../repositories/page_repository.dart';
import '../repositories/overlay_box_repository.dart';

class MigrationService {
  final DatabaseService _dbService;
  final StorageService _storageService;
  final MetadataExtractor _metadataExtractor;
  
  late ComicRepository _comicRepository;
  late PageRepository _pageRepository;
  late OverlayBoxRepository _overlayBoxRepository;

  MigrationService({
    required DatabaseService dbService,
    required StorageService storageService,
    required MetadataExtractor metadataExtractor,
  })  : _dbService = dbService,
        _storageService = storageService,
        _metadataExtractor = metadataExtractor;

  Future<void> initialize() async {
    await _dbService.initializeDatabase();
    _comicRepository = ComicRepository(_dbService);
    _pageRepository = PageRepository(_dbService);
    _overlayBoxRepository = OverlayBoxRepository(_dbService);
  }

  Future<void> migrateFromFolder(String folderPath) async {
    await initialize();

    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      throw Exception('Directory does not exist: $folderPath');
    }

    // Find all folders with images
    final comicFolders = await _findComicFolders(directory);

    for (final comicFolder in comicFolders) {
      await _migrateComicFolder(comicFolder);
    }
  }

  Future<List<Directory>> _findComicFolders(Directory root) async {
    final folders = <Directory>[];
    
    await for (final entity in root.list(recursive: false)) {
      if (entity is Directory) {
        // Check if this directory has image files
        final hasImages = await _hasImageFiles(entity);
        if (hasImages) {
          folders.add(entity);
        }
        
        // Recursively check subdirectories
        final subFolders = await _findComicFolders(entity);
        folders.addAll(subFolders);
      }
    }
    
    return folders;
  }

  Future<bool> _hasImageFiles(Directory dir) async {
    try {
      await for (final entity in dir.list(recursive: false)) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext)) {
            return true;
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return false;
  }

  Future<void> _migrateComicFolder(Directory comicFolder) async {
    try {
      // Get all image files
      final imageFiles = await _getImageFiles(comicFolder);
      if (imageFiles.isEmpty) return;

      // Create comic
      final now = DateTime.now();
      final comicName = comicFolder.path.split(Platform.pathSeparator).last;
      final tempComic = ComicModel(
        title: comicName,
        managedPath: '', // Will be set after import
        createdAt: now,
        updatedAt: now,
      );

      final comicId = await _comicRepository.createComic(tempComic);
      final comicPath = await _storageService.getComicStoragePath(comicId);

      // Update comic with managed path
      await _comicRepository.updateComic(
        tempComic.copyWith(
          comicId: comicId,
          managedPath: comicPath,
        ),
      );

      // Import files and create pages
      final pages = <PageModel>[];
      for (int i = 0; i < imageFiles.length; i++) {
        final file = imageFiles[i];
        
        // Copy file to managed storage
        final importedPath = await _storageService.importFile(file, comicId);
        
        // Extract metadata
        final metadata = await _metadataExtractor.extractMetadata(File(importedPath));
        
        // Create page
        final page = PageModel(
          comicId: comicId,
          pageNumber: i + 1,
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

        // Migrate JSON translations if they exist
        await _migrateTranslations(file, pageId);
      }

      // Set cover page to first page
      if (pages.isNotEmpty && pages.first.pageId != null) {
        await _comicRepository.updateComic(
          tempComic.copyWith(
            comicId: comicId,
            coverPageId: pages.first.pageId,
            coverImagePath: pages.first.storagePath,
          ),
        );
      }
    } catch (e) {
      // Log error but continue with other folders
      print('Error migrating folder ${comicFolder.path}: $e');
    }
  }

  Future<List<File>> _getImageFiles(Directory dir) async {
    final files = <File>[];
    
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final ext = path.extension(entity.path).toLowerCase();
        if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext)) {
          files.add(entity);
        }
      }
    }
    
    // Sort by filename
    files.sort((a, b) => a.path.compareTo(b.path));
    
    return files;
  }

  Future<void> _migrateTranslations(File imageFile, int pageId) async {
    final jsonPath = '${path.withoutExtension(imageFile.path)}.json';
    final jsonFile = File(jsonPath);
    
    if (!await jsonFile.exists()) return;

    try {
      final jsonString = await jsonFile.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);
      final translations = jsonList.map((json) => Translation.fromJson(json)).toList();

      final now = DateTime.now();
      for (final translation in translations) {
        final overlayBox = OverlayBoxModel(
          pageId: pageId,
          x: translation.left,
          y: translation.top,
          width: translation.right - translation.left,
          height: translation.bottom - translation.top,
          translatedText: translation.text,
          createdAt: now,
          updatedAt: now,
        );
        await _overlayBoxRepository.createOverlayBox(overlayBox);
      }
    } catch (e) {
      // Log error but continue
      print('Error migrating translations for ${imageFile.path}: $e');
    }
  }
}








