import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../services/settings_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../models/comic.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiBaseUrlController = TextEditingController();
  final TextEditingController _deeplApiKeyController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  
  String? _managedStoragePath;
  String _storageUsage = 'Calculating...';
  bool _isTestingConnection = false;
  GalleryDisplayMode? _defaultDisplayMode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _deeplApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    // Load API Base URL
    final apiBaseUrl = await _dbService.getApiBaseUrl();
    _apiBaseUrlController.text = apiBaseUrl;

    // Load DeepL API Key
    final deeplApiKey = await SettingsService.getDeepLApiKey();
    _deeplApiKeyController.text = deeplApiKey ?? '';

    // Load Display Mode
    final prefs = await SharedPreferences.getInstance();
    final displayModeIndex = prefs.getInt('display_mode') ?? 0;
    _defaultDisplayMode = GalleryDisplayMode.values[displayModeIndex];

    // Load Storage Path
    _managedStoragePath = await _storageService.getManagedStoragePath();
    await _calculateStorageUsage();

    setState(() => _isLoading = false);
  }

  Future<void> _calculateStorageUsage() async {
    if (_managedStoragePath == null) return;

    try {
      final directory = Directory(_managedStoragePath!);
      if (!await directory.exists()) {
        setState(() => _storageUsage = '0 B');
        return;
      }

      int totalSize = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      setState(() {
        _storageUsage = _formatBytes(totalSize);
      });
    } catch (e) {
      setState(() => _storageUsage = 'Error calculating');
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _saveApiBaseUrl() async {
    final url = _apiBaseUrlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('API Base URL cannot be empty', isError: true);
      return;
    }

    try {
      await _dbService.setApiBaseUrl(url);
      _showSnackBar('API Base URL saved successfully');
    } catch (e) {
      _showSnackBar('Failed to save API Base URL: $e', isError: true);
    }
  }

  Future<void> _testConnection() async {
    setState(() => _isTestingConnection = true);
    try {
      final apiBaseUrl = await _dbService.getApiBaseUrl();
      print('Testing connection to: $apiBaseUrl/Health');
      
      final isConnected = await _dbService.testConnection();
      if (isConnected) {
        _showSnackBar('Connection successful!');
      } else {
        _showSnackBar('Connection failed. Check if API is running at $apiBaseUrl', isError: true);
      }
    } catch (e) {
      print('Connection test error: $e');
      final apiBaseUrl = await _dbService.getApiBaseUrl();
      _showSnackBar('Connection error: $e\nCheck if API is running at $apiBaseUrl', isError: true);
    } finally {
      setState(() => _isTestingConnection = false);
    }
  }

  Future<void> _saveDeepLApiKey() async {
    final apiKey = _deeplApiKeyController.text.trim();
    if (apiKey.isEmpty) {
      _showSnackBar('DeepL API Key cannot be empty', isError: true);
      return;
    }

    try {
      await SettingsService.saveDeepLApiKey(apiKey);
      _showSnackBar('DeepL API Key saved successfully');
    } catch (e) {
      _showSnackBar('Failed to save DeepL API Key: $e', isError: true);
    }
  }

  Future<void> _saveDisplayMode(GalleryDisplayMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('display_mode', mode.index);
      setState(() => _defaultDisplayMode = mode);
      _showSnackBar('Display mode saved');
    } catch (e) {
      _showSnackBar('Failed to save display mode: $e', isError: true);
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear all cached data? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        // Clear all preferences except critical ones
        await prefs.remove('display_mode');
        await _loadSettings();
        _showSnackBar('Cache cleared successfully');
      } catch (e) {
        _showSnackBar('Failed to clear cache: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Top bar
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1E1E1E)
                  : Colors.grey[100],
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          // Settings content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // API Settings Section
                _buildSectionHeader('API Settings', Icons.api),
                _buildTextFieldCard(
                  title: 'Backend API Base URL',
                  controller: _apiBaseUrlController,
                  hintText: 'http://localhost:5172/api',
                  onSave: _saveApiBaseUrl,
                ),
                const SizedBox(height: 8),
                _buildActionCard(
                  title: 'Test Connection',
                  subtitle: 'Test connection to backend API',
                  icon: Icons.network_check,
                  onTap: _isTestingConnection ? null : _testConnection,
                  trailing: _isTestingConnection
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                const SizedBox(height: 24),

                // Translation Settings Section
                _buildSectionHeader('Translation Settings', Icons.translate),
                _buildTextFieldCard(
                  title: 'DeepL API Key',
                  controller: _deeplApiKeyController,
                  hintText: 'Enter your DeepL API key',
                  obscureText: true,
                  onSave: _saveDeepLApiKey,
                ),
                const SizedBox(height: 24),

                // Display Settings Section
                _buildSectionHeader('Display Settings', Icons.display_settings),
                _buildDisplayModeCard(),
                const SizedBox(height: 24),

                // Storage Settings Section
                _buildSectionHeader('Storage Settings', Icons.storage),
                _buildInfoCard(
                  title: 'Managed Storage Path',
                  value: _managedStoragePath ?? 'Not available',
                  icon: Icons.folder,
                  onTap: () {
                    if (_managedStoragePath != null) {
                      _openFolderInExplorer(_managedStoragePath!);
                    } else {
                      _showSnackBar('Storage path not available', isError: true);
                    }
                  },
                ),
                const SizedBox(height: 8),
                _buildInfoCard(
                  title: 'Storage Usage',
                  value: _storageUsage,
                  icon: Icons.data_usage,
                ),
                const SizedBox(height: 24),

                // General Section
                _buildSectionHeader('General', Icons.settings),
                _buildInfoCard(
                  title: 'App Version',
                  value: '1.0.0',
                  icon: Icons.info,
                ),
                const SizedBox(height: 8),
                _buildActionCard(
                  title: 'Clear Cache',
                  subtitle: 'Clear all cached preferences',
                  icon: Icons.delete_outline,
                  onTap: _clearCache,
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldCard({
    required String title,
    required TextEditingController controller,
    String? hintText,
    bool obscureText = false,
    required VoidCallback onSave,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: obscureText,
              decoration: InputDecoration(
                hintText: hintText,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: onSave,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFolderInExplorer(String path) async {
    try {
      if (Platform.isWindows) {
        // Windows: use explorer.exe with path
        Process.start('explorer.exe', [path], mode: ProcessStartMode.detached);
      } else if (Platform.isLinux) {
        // Linux: use xdg-open
        Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
      } else if (Platform.isMacOS) {
        // macOS: use open
        Process.start('open', [path], mode: ProcessStartMode.detached);
      } else {
        _showSnackBar('Opening folder is not supported on this platform', isError: true);
      }
    } catch (e) {
      _showSnackBar('Failed to open folder: $e', isError: true);
    }
  }

  Widget _buildActionCard({
    required String title,
    String? subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDestructive = false,
  }) {
    return Card(
      color: isDestructive ? Colors.red.withOpacity(0.1) : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: isDestructive ? Colors.red : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDestructive ? Colors.red : null,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayModeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Default Display Mode',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ...GalleryDisplayMode.values.map((mode) {
              final isSelected = _defaultDisplayMode == mode;
              return RadioListTile<GalleryDisplayMode>(
                title: Text(_getDisplayModeName(mode)),
                value: mode,
                groupValue: _defaultDisplayMode,
                onChanged: (value) {
                  if (value != null) {
                    _saveDisplayMode(value);
                  }
                },
                selected: isSelected,
              );
            }),
          ],
        ),
      ),
    );
  }

  String _getDisplayModeName(GalleryDisplayMode mode) {
    switch (mode) {
      case GalleryDisplayMode.grid:
        return 'Grid View';
      case GalleryDisplayMode.list:
        return 'List View';
      case GalleryDisplayMode.thumbnail:
        return 'Thumbnail';
      case GalleryDisplayMode.minimal:
        return 'Minimal';
      case GalleryDisplayMode.extended:
        return 'Extended';
    }
  }
}

