import '../models/db/creator_model.dart';
import '../services/database_service.dart';

class CreatorRepository {
  final DatabaseService _dbService;

  CreatorRepository(this._dbService);

  Future<int> createCreator(CreatorModel creator) async {
    final apiClient = _dbService.apiClient;
    final data = creator.toMap();
    data.remove('creator_id'); // Remove ID for creation
    return await apiClient.createCreator(data);
  }

  Future<List<CreatorModel>> getAllCreators() async {
    final apiClient = _dbService.apiClient;
    final dataList = await apiClient.getAllCreators();
    return dataList.map((data) => CreatorModel.fromMap(data)).toList();
  }

  Future<List<CreatorModel>> getCreatorsByComicId(int comicId) async {
    final apiClient = _dbService.apiClient;
    final dataList = await apiClient.getCreatorsByComicId(comicId);
    return dataList.map((data) => CreatorModel.fromMap(data)).toList();
  }

  Future<CreatorModel?> getCreatorById(int creatorId) async {
    // Note: This endpoint might not exist in your API
    // You may need to add it or fetch all and filter
    final allCreators = await getAllCreators();
    try {
      return allCreators.firstWhere((creator) => creator.creatorId == creatorId);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateCreator(CreatorModel creator) async {
    if (creator.creatorId == null) throw Exception('Creator ID is required for update');
    final apiClient = _dbService.apiClient;
    final data = creator.toMap();
    await apiClient.updateCreator(creator.creatorId!, data);
  }

  Future<void> deleteCreator(int creatorId) async {
    // Note: This endpoint might not exist in your API
    throw UnimplementedError('deleteCreator requires API endpoint');
  }
}
