import '../models/db/overlay_box_model.dart';
import '../services/database_service.dart';

class OverlayBoxRepository {
  final DatabaseService _dbService;

  OverlayBoxRepository(this._dbService);

  Future<int> createOverlayBox(OverlayBoxModel overlayBox) async {
    final apiClient = _dbService.apiClient;
    final data = overlayBox.toMap();
    data.remove('overlay_id'); // Remove ID for creation
    return await apiClient.createOverlayBox(data);
  }

  Future<List<OverlayBoxModel>> getOverlayBoxesByPageId(int pageId) async {
    final apiClient = _dbService.apiClient;
    final dataList = await apiClient.getOverlayBoxesByPageId(pageId);
    return dataList.map((data) => OverlayBoxModel.fromMap(data)).toList();
  }

  Future<OverlayBoxModel?> getOverlayBoxById(int overlayId) async {
    // Note: This endpoint might not exist in your API
    // You may need to add it or fetch all and filter
    throw UnimplementedError('getOverlayBoxById requires API endpoint');
  }

  Future<void> updateOverlayBox(OverlayBoxModel overlayBox) async {
    if (overlayBox.overlayId == null) throw Exception('Overlay ID is required for update');
    final apiClient = _dbService.apiClient;
    final data = overlayBox.toMap();
    await apiClient.updateOverlayBox(overlayBox.overlayId!, data);
  }

  Future<void> deleteOverlayBox(int overlayId) async {
    final apiClient = _dbService.apiClient;
    await apiClient.deleteOverlayBox(overlayId);
  }

  Future<void> deleteOverlayBoxesByPageId(int pageId) async {
    final apiClient = _dbService.apiClient;
    await apiClient.deleteOverlayBoxesByPageId(pageId);
  }
}
