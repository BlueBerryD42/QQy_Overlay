import '../models/db/tag_model.dart';
import '../services/database_service.dart';

class TagRepository {
  final DatabaseService _dbService;

  TagRepository(this._dbService);

  // Tag Group methods
  Future<int> createTagGroup(TagGroupModel tagGroup) async {
    final apiClient = _dbService.apiClient;
    final data = tagGroup.toMap();
    data.remove('group_id'); // Remove ID for creation
    return await apiClient.createTagGroup(data);
  }

  Future<List<TagGroupModel>> getAllTagGroups() async {
    final apiClient = _dbService.apiClient;
    final dataList = await apiClient.getAllTagGroups();
    return dataList.map((data) => TagGroupModel.fromMap(data)).toList();
  }

  // Tag methods
  Future<int> createTag(TagModel tag) async {
    final apiClient = _dbService.apiClient;
    final data = tag.toMap();
    data.remove('tag_id'); // Remove ID for creation
    return await apiClient.createTag(data);
  }

  Future<List<TagModel>> getAllTags({int? groupId}) async {
    final apiClient = _dbService.apiClient;
    final dataList = await apiClient.getAllTags(groupId: groupId);
    return dataList.map((data) => TagModel.fromMap(data)).toList();
  }

  Future<List<TagModel>> getTagsByComicId(int comicId) async {
    final apiClient = _dbService.apiClient;
    final dataList = await apiClient.getTagsByComicId(comicId);
    return dataList.map((data) => TagModel.fromMap(data)).toList();
  }

  Future<TagModel?> getTagById(int tagId) async {
    // Note: This endpoint might not exist in your API
    // You may need to add it or fetch all and filter
    final allTags = await getAllTags();
    try {
      return allTags.firstWhere((tag) => tag.tagId == tagId);
    } catch (e) {
      return null;
    }
  }
}
