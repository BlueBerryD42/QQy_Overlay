import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// REST API Client for PostgreSQL database operations
/// This replaces direct PostgreSQL connections which don't work with Flutter
/// 
/// You need to set up a backend API server that handles PostgreSQL operations.
/// Example backend endpoints:
/// - POST /api/comics - Create comic
/// - GET /api/comics - Get all comics
/// - GET /api/comics/:id - Get comic by ID
/// - PUT /api/comics/:id - Update comic
/// - DELETE /api/comics/:id - Delete comic
/// - Similar endpoints for pages, overlay_boxes, tags, creators, sources
class DatabaseApiClient {
  static const String _apiBaseUrlKey = 'api_base_url';
  static const String _defaultApiBaseUrl = 'http://localhost:5172/api';

  Future<String> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiBaseUrlKey) ?? _defaultApiBaseUrl;
  }

  Future<void> setApiBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseUrlKey, url);
  }

  Future<Map<String, dynamic>> _get(String endpoint) async {
    final baseUrl = await getApiBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to GET $endpoint: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String endpoint) async {
    final baseUrl = await getApiBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http.get(url);
    
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } else {
      throw Exception('Failed to GET $endpoint: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> data) async {
    final baseUrl = await getApiBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    
    // Accept 200 OK, 201 Created, and 204 No Content
    if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
      if (response.body.isNotEmpty) {
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (e) {
          // If body is not valid JSON, return empty map (common for 204 or string responses)
          return {};
        }
      }
      return {};
    } else {
      throw Exception('Failed to POST $endpoint: ${response.statusCode} ${response.body}');
    }
  }

  Future<Map<String, dynamic>> _put(String endpoint, Map<String, dynamic> data) async {
    final baseUrl = await getApiBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );
    
    // Accept both 200 OK and 204 No Content as success
    if (response.statusCode == 200 || response.statusCode == 204) {
      // 200 OK with response body (optional)
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (e) {
          // If body is not valid JSON, return empty map
          return {};
        }
      }
      // 204 No Content or 200 with empty body - successful but no response body
      return {};
    } else {
      throw Exception('Failed to PUT $endpoint: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> _delete(String endpoint) async {
    final baseUrl = await getApiBaseUrl();
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http.delete(url);
    
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to DELETE $endpoint: ${response.statusCode}');
    }
  }

  // Comic operations
  Future<int> createComic(Map<String, dynamic> comicData) async {
    final result = await _post('/comics', comicData);
    final comicId = (result['comic_id'] as num?)?.toInt();
    if (comicId == null) throw Exception('comic_id not returned from API');
    return comicId;
  }

  Future<Map<String, dynamic>?> getComicById(int comicId) async {
    try {
      return await _get('/comics/$comicId');
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllComics({
    String? status,
    String? searchQuery,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (searchQuery != null) queryParams['search'] = searchQuery;
    if (limit != null) queryParams['limit'] = limit.toString();
    if (offset != null) queryParams['offset'] = offset.toString();

    final queryString = queryParams.isEmpty
        ? ''
        : '?${Uri(queryParameters: queryParams).query}';
    
    return await _getList('/comics$queryString');
  }

  Future<void> updateComic(int comicId, Map<String, dynamic> comicData) async {
    try {
      await _put('/comics/$comicId', comicData);
    } catch (e) {
      throw Exception('Failed to update comic $comicId: $e');
    }
  }

  Future<void> deleteComic(int comicId) async {
    await _delete('/comics/$comicId');
  }

  // Page operations
  Future<int> createPage(Map<String, dynamic> pageData) async {
    final result = await _post('/pages', pageData);
    final pageId = (result['page_id'] as num?)?.toInt();
    if (pageId == null) throw Exception('page_id not returned from API');
    return pageId;
  }

  Future<Map<String, dynamic>?> getPageById(int pageId) async {
    try {
      return await _get('/pages/$pageId');
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPagesByComicId(int comicId) async {
    return await _getList('/comics/$comicId/pages');
  }

  Future<void> updatePage(int pageId, Map<String, dynamic> pageData) async {
    await _put('/pages/$pageId', pageData);
  }

  Future<void> deletePage(int pageId) async {
    await _delete('/pages/$pageId');
  }

  // Overlay box operations
  Future<int> createOverlayBox(Map<String, dynamic> boxData) async {
    final result = await _post('/overlay-boxes', boxData);
    final overlayId = (result['overlay_id'] as num?)?.toInt();
    if (overlayId == null) throw Exception('overlay_id not returned from API');
    return overlayId;
  }

  Future<List<Map<String, dynamic>>> getOverlayBoxesByPageId(int pageId) async {
    return await _getList('/pages/$pageId/overlay-boxes');
  }

  Future<void> updateOverlayBox(int overlayId, Map<String, dynamic> boxData) async {
    await _put('/overlay-boxes/$overlayId', boxData);
  }

  Future<void> deleteOverlayBox(int overlayId) async {
    await _delete('/overlay-boxes/$overlayId');
  }

  Future<void> deleteOverlayBoxesByPageId(int pageId) async {
    await _delete('/pages/$pageId/overlay-boxes');
  }

  // Tag operations
  Future<int> createTag(Map<String, dynamic> tagData) async {
    final result = await _post('/tags', tagData);
    final tagId = (result['tag_id'] as num?)?.toInt();
    if (tagId == null) throw Exception('tag_id not returned from API');
    return tagId;
  }

  Future<List<Map<String, dynamic>>> getAllTags({int? groupId}) async {
    final query = groupId != null ? '?group_id=$groupId' : '';
    return await _getList('/tags$query');
  }

  Future<List<Map<String, dynamic>>> getTagsByComicId(int comicId) async {
    return await _getList('/comics/$comicId/tags');
  }

  Future<int> createTagGroup(Map<String, dynamic> groupData) async {
    final result = await _post('/tag-groups', groupData);
    final groupId = (result['group_id'] as num?)?.toInt();
    if (groupId == null) throw Exception('group_id not returned from API');
    return groupId;
  }

  Future<List<Map<String, dynamic>>> getAllTagGroups() async {
    return await _getList('/tag-groups');
  }

  // Creator operations
  Future<int> createCreator(Map<String, dynamic> creatorData) async {
    final result = await _post('/creators', creatorData);
    final creatorId = (result['creator_id'] as num?)?.toInt();
    if (creatorId == null) throw Exception('creator_id not returned from API');
    return creatorId;
  }

  Future<List<Map<String, dynamic>>> getAllCreators() async {
    return await _getList('/creators');
  }

  Future<List<Map<String, dynamic>>> getCreatorsByComicId(int comicId) async {
    return await _getList('/comics/$comicId/creators');
  }

  Future<void> updateCreator(int creatorId, Map<String, dynamic> creatorData) async {
    await _put('/creators/$creatorId', creatorData);
  }

  // Source operations
  Future<int> createSource(Map<String, dynamic> sourceData) async {
    final result = await _post('/sources', sourceData);
    final sourceId = (result['source_id'] as num?)?.toInt();
    if (sourceId == null) throw Exception('source_id not returned from API');
    return sourceId;
  }

  Future<List<Map<String, dynamic>>> getSourcesByComicId(int comicId) async {
    return await _getList('/comics/$comicId/sources');
  }

  Future<void> updateSource(int sourceId, Map<String, dynamic> sourceData) async {
    await _put('/sources/$sourceId', sourceData);
  }

  // Relationship operations
  Future<void> linkComicTag(int comicId, int tagId) async {
    await _post('/comics/$comicId/tags', {'tag_id': tagId});
  }

  Future<void> unlinkComicTag(int comicId, int tagId) async {
    await _delete('/comics/$comicId/tags/$tagId');
  }

  Future<void> linkComicCreator(int comicId, int creatorId) async {
    await _post('/comics/$comicId/creators', {'creator_id': creatorId});
  }

  Future<void> unlinkComicCreator(int comicId, int creatorId) async {
    await _delete('/comics/$comicId/creators/$creatorId');
  }

  Future<void> linkComicSource(int comicId, int sourceId) async {
    await _post('/comics/$comicId/sources', {'source_id': sourceId});
  }

  // Migration operations
  Future<void> initializeDatabase() async {
    await _post('/migrations/initialize', {});
  }

  Future<List<int>> getAppliedMigrations() async {
    final result = await _getList('/migrations/applied');
    return result.map((m) => (m['version'] as num?)?.toInt() ?? 0).where((v) => v > 0).toList();
  }

  /// Test API connection using health endpoint
  Future<bool> testConnection() async {
    try {
      final baseUrl = await getApiBaseUrl();
      final url = Uri.parse('$baseUrl/health');
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );
      
      if (response.statusCode == 200) {
        return true;
      } else {
        print('Health check failed with status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Health check error: $e');
      return false;
    }
  }

  Future<void> applyMigration(int version, String sql) async {
    await _post('/migrations/apply', {'version': version, 'sql': sql});
  }
}




