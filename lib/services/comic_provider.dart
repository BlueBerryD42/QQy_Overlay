import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/comic.dart';

class ComicProvider with ChangeNotifier {
  List<Comic> _comics = [];
  FolderNode? _rootFolder;
  String _currentPath = '';
  List<BreadcrumbItem> _breadcrumbs = [];
  bool _isLoading = false;

  List<Comic> get comics => _comics;
  FolderNode? get rootFolder => _rootFolder;
  String get currentPath => _currentPath;
  List<BreadcrumbItem> get breadcrumbs => _breadcrumbs;
  bool get isLoading => _isLoading;

  Future<void> loadComics(String path) async {
    _isLoading = true;
    notifyListeners();

    _comics.clear();
    _rootFolder = null;
    _currentPath = path;
    _breadcrumbs = [BreadcrumbItem(name: 'Home', path: path, isClickable: false)];

    final comicsDir = Directory(path);
    if (await comicsDir.exists()) {
      _rootFolder = await _buildFolderStructure(comicsDir, isRoot: true);
      await _loadCurrentDirectory();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> navigateToFolder(String folderPath) async {
    _isLoading = true;
    notifyListeners();

    _currentPath = folderPath;
    await _loadCurrentDirectory();
    _updateBreadcrumbs(folderPath);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> navigateToBreadcrumb(String path) async {
    if (path == _currentPath) return;
    
    _isLoading = true;
    notifyListeners();

    _currentPath = path;
    await _loadCurrentDirectory();
    _updateBreadcrumbs(path);

    _isLoading = false;
    notifyListeners();
  }

  // Add this new method for parent navigation
  Future<void> navigateToParent() async {
    if (_rootFolder == null) return;
    
    // Don't go back if already at root
    if (_currentPath == _rootFolder!.fullPath) return;
    
    _isLoading = true;
    notifyListeners();

    // Find parent path by going up one level
    final parentPath = _getParentPath(_currentPath);
    if (parentPath != null && parentPath != _currentPath) {
      _currentPath = parentPath;
      await _loadCurrentDirectory();
      _updateBreadcrumbs(_currentPath);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Helper method to get parent directory path
  String? _getParentPath(String currentPath) {
    if (_rootFolder == null) return null;
    
    final rootPath = _rootFolder!.fullPath;
    
    // If already at root, return null
    if (currentPath == rootPath) return null;
    
    // Split the path and remove the last component
    final pathParts = currentPath.split(Platform.pathSeparator);
    if (pathParts.length <= 1) return null;
    
    // Reconstruct path without the last part
    final parentParts = pathParts.sublist(0, pathParts.length - 1);
    final parentPath = parentParts.join(Platform.pathSeparator);
    
    // Make sure we don't go above the root directory
    final rootParts = rootPath.split(Platform.pathSeparator);
    if (parentParts.length < rootParts.length) {
      return rootPath;
    }
    
    return parentPath;
  }

  // Helper method to check if we can go back (not at root)
  bool canNavigateBack() {
    if (_rootFolder == null) return false;
    return _currentPath != _rootFolder!.fullPath;
  }

  Future<void> _loadCurrentDirectory() async {
    _comics.clear();
    
    if (_rootFolder == null) return;

    final currentFolder = _findFolderByPath(_currentPath);
    if (currentFolder != null) {
      // Add comics from current folder
      if (currentFolder.hasImages) {
        _comics.add(Comic(
          name: currentFolder.name,
          images: currentFolder.images,
        ));
      }
      
      // Add comics from subfolders
      for (final subfolder in currentFolder.subfolders) {
        if (subfolder.hasImages) {
          _comics.add(Comic(
            name: subfolder.name,
            images: subfolder.images,
          ));
        }
      }
    }
  }

  FolderNode? _findFolderByPath(String path) {
    if (_rootFolder == null) return null;
    
    if (_rootFolder!.fullPath == path) {
      return _rootFolder;
    }
    
    return _findFolderRecursively(_rootFolder!, path);
  }

  FolderNode? _findFolderRecursively(FolderNode folder, String targetPath) {
    if (folder.fullPath == targetPath) {
      return folder;
    }
    
    for (final subfolder in folder.subfolders) {
      final found = _findFolderRecursively(subfolder, targetPath);
      if (found != null) return found;
    }
    
    return null;
  }

  void _updateBreadcrumbs(String currentPath) {
    if (_rootFolder == null) return;
    
    final pathParts = currentPath.split(Platform.pathSeparator);
    final rootPath = _rootFolder!.fullPath;
    final rootParts = rootPath.split(Platform.pathSeparator);
    
    _breadcrumbs = [
      BreadcrumbItem(name: 'Home', path: rootPath, isClickable: true),
    ];
    
    for (int i = rootParts.length; i < pathParts.length; i++) {
      final part = pathParts[i];
      final path = pathParts.take(i + 1).join(Platform.pathSeparator);
      _breadcrumbs.add(BreadcrumbItem(
        name: part,
        path: path,
        isClickable: true,
      ));
    }
    
    // Make the current breadcrumb non-clickable
    if (_breadcrumbs.isNotEmpty) {
      final lastIndex = _breadcrumbs.length - 1;
      _breadcrumbs[lastIndex] = BreadcrumbItem(
        name: _breadcrumbs[lastIndex].name,
        path: _breadcrumbs[lastIndex].path,
        isClickable: false,
      );
    }
  }

  Future<FolderNode> _buildFolderStructure(Directory directory, {bool isRoot = false}) async {
    try {
      final entities = directory.listSync();
      final List<File> imageFiles = [];
      final List<FolderNode> subfolders = [];
      
      for (final entity in entities) {
        if (entity is File) {
          // Check if it's an image file
          if (entity.path.endsWith('.jpg') ||
              entity.path.endsWith('.jpeg') ||
              entity.path.endsWith('.png') ||
              entity.path.endsWith('.gif') ||
              entity.path.endsWith('.webp') ||
              entity.path.endsWith('.bmp')) {
            imageFiles.add(entity);
          }
        } else if (entity is Directory) {
          // Recursively build subfolder structure
          final subfolder = await _buildFolderStructure(entity);
          if (!subfolder.isEmpty) {
            subfolders.add(subfolder);
          }
        }
      }

      // Sort images by name for consistent ordering
      imageFiles.sort((a, b) => a.path.compareTo(b.path));
      
      return FolderNode(
        name: directory.path.split(Platform.pathSeparator).last,
        fullPath: directory.path,
        images: imageFiles,
        subfolders: subfolders,
        isRoot: isRoot,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error building folder structure for ${directory.path}: $e');
      }
      return FolderNode(
        name: directory.path.split(Platform.pathSeparator).last,
        fullPath: directory.path,
        images: [],
        subfolders: [],
        isRoot: isRoot,
      );
    }
  }

  void _extractComicsFromFolders(FolderNode folder) {
    // Add comics from this folder if it has images
    if (folder.hasImages) {
      _comics.add(Comic(
        name: folder.name,
        images: folder.images,
      ));
    }
    
    // Recursively extract comics from subfolders
    for (final subfolder in folder.subfolders) {
      _extractComicsFromFolders(subfolder);
    }
  }
}