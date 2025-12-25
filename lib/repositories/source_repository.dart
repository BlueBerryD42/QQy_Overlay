import '../models/db/source_model.dart';
import '../services/database_service.dart';

class SourceRepository {
  final DatabaseService _dbService;

  SourceRepository(this._dbService);

  Future<int> createSource(SourceModel source) async {
    final apiClient = _dbService.apiClient;
    final data = source.toMap();
    data.remove('source_id'); // Remove ID for creation
    return await apiClient.createSource(data);
  }

  Future<List<SourceModel>> getSourcesByComicId(int comicId) async {
    final apiClient = _dbService.apiClient;
    final dataList = await apiClient.getSourcesByComicId(comicId);
    return dataList.map((data) => SourceModel.fromMap(data)).toList();
  }

  Future<void> updateSource(SourceModel source) async {
    if (source.sourceId == null) throw Exception('Source ID is required for update');
    final apiClient = _dbService.apiClient;
    final data = source.toMap();
    data.remove('source_id'); // Remove ID from update data
    data.remove('discovered_at'); // Don't update discovered_at
    await apiClient.updateSource(source.sourceId!, data);
  }
}
