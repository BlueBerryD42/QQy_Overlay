import '../models/db/page_model.dart';
import '../services/database_service.dart';

class PageRepository {
  final DatabaseService _dbService;

  PageRepository(this._dbService);

  Future<int> createPage(PageModel page) async {
    final apiClient = _dbService.apiClient;
    final data = page.toMap();
    data.remove('page_id'); // Remove ID for creation
    return await apiClient.createPage(data);
  }

  Future<PageModel?> getPageById(int pageId) async {
    final apiClient = _dbService.apiClient;
    final data = await apiClient.getPageById(pageId);
    if (data == null) return null;
    return PageModel.fromMap(data);
  }

  Future<List<PageModel>> getPagesByComicId(int comicId) async {
    final apiClient = _dbService.apiClient;
    final dataList = await apiClient.getPagesByComicId(comicId);
    return dataList.map((data) => PageModel.fromMap(data)).toList();
  }

  Future<void> updatePage(PageModel page) async {
    if (page.pageId == null) throw Exception('Page ID is required for update');
    final apiClient = _dbService.apiClient;
    final data = page.toMap();
    await apiClient.updatePage(page.pageId!, data);
  }

  Future<void> deletePage(int pageId) async {
    final apiClient = _dbService.apiClient;
    await apiClient.deletePage(pageId);
  }

  Future<void> deletePagesByComicId(int comicId) async {
    final apiClient = _dbService.apiClient;
    final pages = await getPagesByComicId(comicId);
    for (final page in pages) {
      if (page.pageId != null) {
        await apiClient.deletePage(page.pageId!);
      }
    }
  }
}
