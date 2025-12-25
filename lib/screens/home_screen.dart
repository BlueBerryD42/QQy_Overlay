import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/comic_provider.dart';
import '../models/comic.dart';
import '../widgets/app_sidebar.dart';
import 'gallery_screen.dart';
import 'import_screen.dart';
import 'settings_screen.dart';
import 'tag_management_screen.dart';
import 'creator_management_screen.dart';
import 'webview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GalleryDisplayMode _displayMode = GalleryDisplayMode.grid;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  NavigationItem _selectedNavItem = NavigationItem.home;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadComics());
    _loadDisplayMode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AppSidebar(
            selectedItem: _selectedNavItem,
            onItemSelected: _handleNavigation,
          ),
          // Main content area
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Handle different navigation items
    switch (_selectedNavItem) {
      case NavigationItem.home:
        return _buildHomeContent();
      case NavigationItem.tags:
        return const TagManagementScreen();
      case NavigationItem.creators:
        return const CreatorManagementScreen();
      case NavigationItem.favorites:
        return _buildPlaceholderContent('Favorites', Icons.favorite);
      case NavigationItem.webview:
        return const WebViewScreen(
          initialUrl: 'https://grok.com/',
          title: 'Grok AI',
        );
      case NavigationItem.settings:
        return const SettingsScreen();
    }
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        // Top bar with title and actions
        _buildTopBar(),
        // Main content
        Expanded(
          child: Consumer<ComicProvider>(
            builder: (context, comicProvider, child) {
              if (comicProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (comicProvider.comics.isEmpty) {
                return _buildEmptyState();
              }

              return _buildGalleryContent(comicProvider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderContent(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon...',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  void _handleNavigation(NavigationItem item) {
    setState(() {
      _selectedNavItem = item;
    });
  }

  Widget _buildTopBar() {
    return Container(
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
            'Comics',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const Spacer(),
          // Search bar
          SizedBox(
            width: 300,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search comics...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
                Provider.of<ComicProvider>(context, listen: false)
                    .search(_searchQuery);
              },
            ),
          ),
          const SizedBox(width: 12),
          // Display mode button
          _buildDisplayModeButton(),
          const SizedBox(width: 8),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComics,
            tooltip: 'Refresh gallery',
          ),
          const SizedBox(width: 8),
          // Import button
          ElevatedButton.icon(
            onPressed: _openImportScreen,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Import'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuButton<GalleryDisplayMode> _buildDisplayModeButton() {
    return PopupMenuButton<GalleryDisplayMode>(
      icon: Icon(_getDisplayModeIcon()),
      tooltip: 'Change display mode',
      onSelected: _changeDisplayMode,
      itemBuilder: (context) => [
        _buildDisplayModeMenuItem(
          value: GalleryDisplayMode.grid,
          icon: Icons.grid_view,
          text: 'Grid View',
        ),
        _buildDisplayModeMenuItem(
          value: GalleryDisplayMode.list,
          icon: Icons.view_list,
          text: 'List View',
        ),
        _buildDisplayModeMenuItem(
          value: GalleryDisplayMode.thumbnail,
          icon: Icons.photo_size_select_large,
          text: 'Thumbnail',
        ),
        _buildDisplayModeMenuItem(
          value: GalleryDisplayMode.minimal,
          icon: Icons.view_compact,
          text: 'Minimal',
        ),
        _buildDisplayModeMenuItem(
          value: GalleryDisplayMode.extended,
          icon: Icons.view_comfortable,
          text: 'Extended',
        ),
      ],
    );
  }

  PopupMenuItem<GalleryDisplayMode> _buildDisplayModeMenuItem({
    required GalleryDisplayMode value,
    required IconData icon,
    required String text,
  }) {
    return PopupMenuItem<GalleryDisplayMode>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.library_books, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No comics found.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Import your first comic to get started.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openImportScreen,
            icon: const Icon(Icons.add),
            label: const Text('Import Comic'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildGalleryContent(ComicProvider comicProvider) {
    final filteredComics = _searchQuery.isEmpty
        ? comicProvider.comics
        : comicProvider.comics
            .where((comic) => comic.name.toLowerCase().contains(_searchQuery))
            .toList();

    if (filteredComics.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoResultsFound();
    }

    if (filteredComics.isEmpty) {
      return _buildNoGalleriesFound();
    }

    return CustomScrollView(
      slivers: [
        // Section header removed since we have it in top bar
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${filteredComics.length} comic(s)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
        ),
        _buildGalleryView(filteredComics, comicProvider),
      ],
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No galleries found matching "$_searchQuery"'),
        ],
      ),
    );
  }

  Widget _buildNoGalleriesFound() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No galleries found in the current directory.'),
        ],
      ),
    );
  }

  Widget _buildGalleryView(List<Comic> comics, ComicProvider comicProvider) {
    switch (_displayMode) {
      case GalleryDisplayMode.grid:
        return _buildGridView(comics, comicProvider);
      case GalleryDisplayMode.list:
        return _buildListView(comics, comicProvider);
      case GalleryDisplayMode.thumbnail:
        return _buildThumbnailView(comics, comicProvider);
      case GalleryDisplayMode.minimal:
        return _buildMinimalView(comics, comicProvider);
      case GalleryDisplayMode.extended:
        return _buildExtendedView(comics, comicProvider);
    }
  }

  Widget _buildGridView(List<Comic> comics, ComicProvider comicProvider) {
    // Calculate cross axis count based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 240 - 32; // sidebar width + padding
    final crossAxisCount = (availableWidth / 180).floor().clamp(2, 8);

    return SliverPadding(
      padding: const EdgeInsets.all(16.0),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final comic = comics[index];
            return _buildGalleryCard(comic, comicProvider);
          },
          childCount: comics.length,
        ),
      ),
    );
  }

  Widget _buildListView(List<Comic> comics, ComicProvider comicProvider) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final comic = comics[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  comic.images.first,
                  width: 50,
                  height: 70,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(comic.name),
              subtitle: Text('${comic.images.length} pages'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _openGallery(comic),
            ),
          );
        },
        childCount: comics.length,
      ),
    );
  }

  Widget _buildThumbnailView(List<Comic> comics, ComicProvider comicProvider) {
    return SliverPadding(
      padding: const EdgeInsets.all(8.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.75,
          crossAxisSpacing: 4.0,
          mainAxisSpacing: 4.0,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final comic = comics[index];
            return InkWell(
              onTap: () => _openGallery(comic),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        comic.images.first,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comic.name,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
          childCount: comics.length,
        ),
      ),
    );
  }

  Widget _buildMinimalView(List<Comic> comics, ComicProvider comicProvider) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final comic = comics[index];
          return ListTile(
            dense: true,
            title: Text(comic.name),
            subtitle: Text('${comic.images.length} pages'),
            onTap: () => _openGallery(comic),
          );
        },
        childCount: comics.length,
      ),
    );
  }

  Widget _buildExtendedView(List<Comic> comics, ComicProvider comicProvider) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final comic = comics[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: InkWell(
                onTap: () => _openGallery(comic),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        comic.images.first,
                        width: 80,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comic.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.photo, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${comic.images.length} pages',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(
                              Icons.arrow_forward,
                              size: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        childCount: comics.length,
      ),
    );
  }

  Widget _buildGalleryCard(Comic comic, ComicProvider comicProvider) {
    return InkWell(
      onTap: () => _openGallery(comic),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
        elevation: 5.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Hero(
                tag: 'comic-${comic.images.first.path}',
                child: Image.file(
                  comic.images.first,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comic.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${comic.images.length} pages',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGallery(Comic comic) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryScreen(comic: comic),
      ),
    );
    
    // If comic was deleted or updated, refresh the list
    if (result == true) {
      _loadComics();
    }
  }

  IconData _getDisplayModeIcon() {
    switch (_displayMode) {
      case GalleryDisplayMode.grid:
        return Icons.grid_view;
      case GalleryDisplayMode.list:
        return Icons.view_list;
      case GalleryDisplayMode.thumbnail:
        return Icons.photo_size_select_large;
      case GalleryDisplayMode.minimal:
        return Icons.view_compact;
      case GalleryDisplayMode.extended:
        return Icons.view_comfortable;
    }
  }

  Future<void> _loadComics() async {
    await Provider.of<ComicProvider>(context, listen: false).loadComics(
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );
  }

  Future<void> _openImportScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ImportScreen()),
    );

    if (result == true) {
      // Refresh comics after import
      await _loadComics();
    }
  }

  Future<void> _loadDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final displayModeIndex = prefs.getInt('display_mode') ?? 0;
    setState(() {
      _displayMode = GalleryDisplayMode.values[displayModeIndex];
    });
  }

  Future<void> _changeDisplayMode(GalleryDisplayMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('display_mode', mode.index);
    setState(() {
      _displayMode = mode;
    });
  }

}
