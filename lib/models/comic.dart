
import 'dart:io';

class Comic {
  final String name;
  final List<File> images;

  Comic({required this.name, required this.images});
}

class FolderNode {
  final String name;
  final String fullPath;
  final List<File> images;
  final List<FolderNode> subfolders;
  final bool isRoot;

  FolderNode({
    required this.name,
    required this.fullPath,
    this.images = const [],
    this.subfolders = const [],
    this.isRoot = false,
  });

  bool get hasImages => images.isNotEmpty;
  bool get hasSubfolders => subfolders.isNotEmpty;
  bool get isEmpty => !hasImages && !hasSubfolders;
}

enum GalleryDisplayMode { grid, list, thumbnail, minimal, extended }

class BreadcrumbItem {
  final String name;
  final String path;
  final bool isClickable;

  BreadcrumbItem({
    required this.name,
    required this.path,
    this.isClickable = true,
  });
}
