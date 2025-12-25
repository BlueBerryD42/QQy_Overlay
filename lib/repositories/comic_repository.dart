import '../models/db/comic_model.dart';
import '../services/database_service.dart';

class ComicRepository {
  final DatabaseService _dbService;

  ComicRepository(this._dbService);

  Future<int> createComic(ComicModel comic) async {
    final apiClient = _dbService.apiClient;
    final data = comic.toMap();
    data.remove('comic_id'); // Remove ID for creation
    return await apiClient.createComic(data);
  }

  Future<ComicModel?> getComicById(int comicId) async {
    final apiClient = _dbService.apiClient;
    final data = await apiClient.getComicById(comicId);
    if (data == null) return null;
    return ComicModel.fromMap(data);
  }

  Future<List<ComicModel>> getAllComics({
    String? status,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final apiClient = _dbService.apiClient;
    final dataList = await apiClient.getAllComics(
      status: status,
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );
    return dataList.map((data) => ComicModel.fromMap(data)).toList();
  }

  Future<void> updateComic(ComicModel comic) async {
    if (comic.comicId == null) throw Exception('Comic ID is required for update');
    final apiClient = _dbService.apiClient;
    final data = comic.toMap();
    await apiClient.updateComic(comic.comicId!, data);
  }

  Future<void> deleteComic(int comicId) async {
    final apiClient = _dbService.apiClient;
    await apiClient.deleteComic(comicId);
  }

  Future<void> linkCreator(int comicId, int creatorId) async {
    final apiClient = _dbService.apiClient;
    await apiClient.linkComicCreator(comicId, creatorId);
  }

  Future<void> unlinkCreator(int comicId, int creatorId) async {
    final apiClient = _dbService.apiClient;
    await apiClient.unlinkComicCreator(comicId, creatorId);
  }

  Future<void> linkTag(int comicId, int tagId) async {
    final apiClient = _dbService.apiClient;
    await apiClient.linkComicTag(comicId, tagId);
  }

  Future<void> unlinkTag(int comicId, int tagId) async {
    final apiClient = _dbService.apiClient;
    await apiClient.unlinkComicTag(comicId, tagId);
  }

  Future<void> linkSource(int comicId, int sourceId) async {
    final apiClient = _dbService.apiClient;
    await apiClient.linkComicSource(comicId, sourceId);
  }

  Future<List<Map<String, dynamic>>> getComicTags(int comicId) async {
    final apiClient = _dbService.apiClient;
    return await apiClient.getTagsByComicId(comicId);
  }

  Future<List<Map<String, dynamic>>> getComicCreators(int comicId) async {
    final apiClient = _dbService.apiClient;
    return await apiClient.getCreatorsByComicId(comicId);
  }

  Future<List<Map<String, dynamic>>> getComicSources(int comicId) async {
    final apiClient = _dbService.apiClient;
    return await apiClient.getSourcesByComicId(comicId);
  }
}
