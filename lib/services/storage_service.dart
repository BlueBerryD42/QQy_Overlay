import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class StorageService {
  static const String _managedStorageFolder = 'comics';

  Future<String> getManagedStoragePath() async {
    final appDir = await getApplicationSupportDirectory();
    final managedPath = path.join(appDir.path, _managedStorageFolder);
    
    // Ensure directory exists
    final dir = Directory(managedPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return managedPath;
  }

  Future<String> getComicStoragePath(int comicId) async {
    final managedPath = await getManagedStoragePath();
    final comicPath = path.join(managedPath, comicId.toString());
    
    // Ensure directory exists
    final dir = Directory(comicPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    
    return comicPath;
  }

  Future<String> importFile(File sourceFile, int comicId, {String? customFileName}) async {
    final comicPath = await getComicStoragePath(comicId);
    final fileName = customFileName ?? sourceFile.path.split(Platform.pathSeparator).last;
    final destPath = path.join(comicPath, fileName);
    final destFile = File(destPath);
    
    // Copy file
    await sourceFile.copy(destPath);
    
    return destPath;
  }

  Future<List<String>> importDirectory(Directory sourceDir, int comicId) async {
    final comicPath = await getComicStoragePath(comicId);
    final importedPaths = <String>[];
    
    // Get all files in source directory (recursively)
    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity is File) {
        // Check if it's an image file
        final ext = path.extension(entity.path).toLowerCase();
        if (_isImageFile(ext)) {
          final relativePath = path.relative(entity.path, from: sourceDir.path);
          final destPath = path.join(comicPath, relativePath);
          
          // Create parent directories if needed
          final destFile = File(destPath);
          await destFile.parent.create(recursive: true);
          
          // Copy file
          await entity.copy(destPath);
          importedPaths.add(destPath);
        }
      }
    }
    
    return importedPaths;
  }

  Future<List<String>> importFiles(List<File> sourceFiles, int comicId) async {
    final importedPaths = <String>[];
    
    for (final sourceFile in sourceFiles) {
      if (await sourceFile.exists()) {
        final ext = path.extension(sourceFile.path).toLowerCase();
        if (_isImageFile(ext)) {
          final path = await importFile(sourceFile, comicId);
          importedPaths.add(path);
        }
      }
    }
    
    return importedPaths;
  }

  Future<void> deleteComicStorage(int comicId) async {
    final comicPath = await getComicStoragePath(comicId);
    final dir = Directory(comicPath);
    
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<File?> getComicFile(int comicId, String relativePath) async {
    final comicPath = await getComicStoragePath(comicId);
    final filePath = path.join(comicPath, relativePath);
    final file = File(filePath);
    
    if (await file.exists()) {
      return file;
    }
    
    return null;
  }

  Future<Directory?> getComicDirectory(int comicId) async {
    final comicPath = await getComicStoragePath(comicId);
    final dir = Directory(comicPath);
    
    if (await dir.exists()) {
      return dir;
    }
    
    return null;
  }

  Future<int> getStorageSize() async {
    final managedPath = await getManagedStoragePath();
    final dir = Directory(managedPath);
    
    if (!await dir.exists()) {
      return 0;
    }
    
    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    
    return totalSize;
  }

  bool _isImageFile(String extension) {
    const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.tif'];
    return imageExtensions.contains(extension.toLowerCase());
  }
}








