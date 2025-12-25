import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/comic.dart';
import '../models/db/comic_model.dart';
import '../models/db/page_model.dart';
import '../services/database_service.dart';
import '../repositories/comic_repository.dart';
import '../repositories/page_repository.dart';

class ComicProvider with ChangeNotifier {
  List<Comic> _comics = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _statusFilter;

  final DatabaseService _dbService = DatabaseService();
  ComicRepository? _comicRepository;
  PageRepository? _pageRepository;

  List<Comic> get comics => _comics;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  Future<void> initialize() async {
    await _dbService.initializeDatabase();
    _comicRepository = ComicRepository(_dbService);
    _pageRepository = PageRepository(_dbService);
  }

  Future<void> loadComics({String? searchQuery, String? status}) async {
    if (_comicRepository == null || _pageRepository == null) {
      await initialize();
    }

    _isLoading = true;
    _searchQuery = searchQuery ?? '';
    _statusFilter = status;
    notifyListeners();

    try {
      final comicModels = await _comicRepository!.getAllComics(
        status: _statusFilter,
        searchQuery: _searchQuery,
      );

      _comics = [];
      
      for (final comicModel in comicModels) {
        // Load pages for each comic
        final pages = await _pageRepository!.getPagesByComicId(comicModel.comicId!);
        
        // Convert pages to File objects
        final imageFiles = pages
            .map((page) => File(page.storagePath))
            .where((file) => file.existsSync())
            .toList();

        if (imageFiles.isNotEmpty) {
          _comics.add(Comic(
            name: comicModel.title,
            images: imageFiles,
            comicId: comicModel.comicId,
            comicModel: comicModel,
          ));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading comics: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadComics(searchQuery: _searchQuery, status: _statusFilter);
  }

  Future<void> search(String query) async {
    await loadComics(searchQuery: query, status: _statusFilter);
  }

  Future<void> filterByStatus(String? status) async {
    await loadComics(searchQuery: _searchQuery, status: status);
  }

  Future<void> deleteComic(int comicId) async {
    if (_comicRepository == null) {
      await initialize();
    }

    try {
      await _comicRepository!.deleteComic(comicId);
      await refresh();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting comic: $e');
      }
      rethrow;
    }
  }

  @override
  void dispose() {
    _dbService.dispose();
    super.dispose();
  }
}
