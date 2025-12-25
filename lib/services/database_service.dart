import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_api_client.dart';

/// Database Service using REST API backend
/// This service connects to a backend API that handles PostgreSQL operations
class DatabaseService {
  static const String _apiBaseUrlKey = 'api_base_url';
  static const String _defaultApiBaseUrl = 'http://localhost:5172/api';

  final DatabaseApiClient _apiClient = DatabaseApiClient();
  bool _isInitialized = false;

  Future<String> getApiBaseUrl() async {
    return await _apiClient.getApiBaseUrl();
  }

  Future<void> setApiBaseUrl(String url) async {
    await _apiClient.setApiBaseUrl(url);
  }

  Future<bool> testConnection() async {
    try {
      // Use health endpoint for connection test
      return await _apiClient.testConnection();
    } catch (e) {
      return false;
    }
  }

  Future<void> initializeDatabase() async {
    if (_isInitialized) return;
    
    try {
      await _apiClient.initializeDatabase();
      _isInitialized = true;
    } catch (e) {
      // If initialization fails, migrations might already be applied
      // This is okay - the backend should handle it
      _isInitialized = true;
    }
  }

  DatabaseApiClient get apiClient => _apiClient;

  Future<void> close() async {
    // REST API doesn't need explicit closing
    _isInitialized = false;
  }

  Future<void> dispose() async {
    await close();
  }
}
