import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

import '../services/comic_provider.dart';
import '../models/comic.dart';
import 'gallery_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _comicsPath;
  GalleryDisplayMode _displayMode = GalleryDisplayMode.grid;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
      appBar: _buildAppBar(),
      body: Consumer<ComicProvider>(
        builder: (context, comicProvider, child) {
          if (comicProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_comicsPath == null) {
            return _buildEmptyState();
          }

          final breadcrumbs = _buildBreadcrumbs(comicProvider);
          final galleryContent = _buildGalleryContent(comicProvider);

          return Column(
            children: [
              breadcrumbs,
              Expanded(child: galleryContent),
            ],
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('QRganize - Gallery'),
      // Add leading back button when not at root
      leading: Consumer<ComicProvider>(
        builder: (context, comicProvider, child) {
          // Show back button if we can navigate back
          if (comicProvider.canNavigateBack()) {
            return IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _navigateBack(comicProvider),
              tooltip: 'Go back',
            );
          }
          return const SizedBox.shrink(); // Use default leading widget
        },
      ),
      actions: [
        _buildDisplayModeButton(),
        IconButton(
          icon: const Icon(Icons.folder_open),
          onPressed: _selectComicsDirectory,
          tooltip: 'Select comics directory',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadComics,
          tooltip: 'Refresh gallery',
        ),
      ],
      bottom: _buildSearchBar(),
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

  PreferredSize _buildSearchBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(60),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search galleries...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value.toLowerCase());
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Please select your comics directory.'),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(ComicProvider comicProvider) {
    if (comicProvider.breadcrumbs.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Home button
              InkWell(
                onTap: () => comicProvider.navigateToFolder(_comicsPath!),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.home,
                    size: 16,
                    color: theme.primaryColorLight,
                  ),
                ),
              ),

              // Only show breadcrumbs if there are actual path segments beyond root
              if (comicProvider.breadcrumbs.length > 1 || 
                  (comicProvider.breadcrumbs.isNotEmpty && comicProvider.breadcrumbs.first.name != 'Home')) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),

                // Breadcrumb items (skip the first 'Home' item since we have the home button)
                ...comicProvider.breadcrumbs
                    .where((item) => item.name != 'Home')
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final filteredBreadcrumbs = comicProvider.breadcrumbs
                      .where((item) => item.name != 'Home')
                      .toList();
                  final isLast = index == filteredBreadcrumbs.length - 1;
                  final isClickable = item.isClickable;

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: isClickable
                            ? () => comicProvider.navigateToBreadcrumb(item.path)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: !isClickable
                                ? theme.primaryColor.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.name,
                            style: TextStyle(
                              color: !isClickable
                                  ? theme.primaryColor
                                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
                              fontWeight: !isClickable ? FontWeight.w600 : FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      if (!isLast) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  );
                }).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryContent(ComicProvider comicProvider) {
    final filteredComics = comicProvider.comics
        .where((comic) => comic.name.toLowerCase().contains(_searchQuery))
        .toList();

    if (filteredComics.isEmpty && _searchQuery.isNotEmpty) {
      return _buildNoResultsFound();
    }

    final currentFolder = comicProvider.rootFolder != null
        ? _findFolderByPath(comicProvider.currentPath, comicProvider.rootFolder!)
        : null;

    final subfolders = currentFolder?.subfolders ?? [];

    if (subfolders.isEmpty && filteredComics.isEmpty) {
      return _buildNoGalleriesFound();
    }

    return CustomScrollView(
      slivers: [
        if (subfolders.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.folder,
            title: 'Folders',
            color: Colors.orange[600]!,
          ),
          _buildSubfolderGrid(subfolders, comicProvider),
        ],
        if (filteredComics.isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.photo_library,
            title: 'Galleries',
            color: Colors.blue[600]!,
          ),
          _buildGalleryView(filteredComics, comicProvider),
        ],
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

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildSubfolderGrid(
  List<FolderNode> subfolders,
  ComicProvider comicProvider,
) {
  return SliverList(
    delegate: SliverChildBuilderDelegate(
      (context, index) {
        final subfolder = subfolders[index];
        return InkWell(
          onTap: () => comicProvider.navigateToFolder(subfolder.fullPath),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 20,
                  color: Colors.orange[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subfolder.name,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (subfolder.hasImages)
                  Text(
                    '${subfolder.images.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
              ],
            ),
          ),
        );
      },
      childCount: subfolders.length,
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
    return SliverPadding(
      padding: const EdgeInsets.all(8.0),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 8.0,
          mainAxisSpacing: 8.0,
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
                tag: 'comic-${comic.name}',
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

  void _openGallery(Comic comic) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryScreen(comic: comic),
      ),
    );
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
    final prefs = await SharedPreferences.getInstance();
    final comicsPath = prefs.getString('comics_path');
    setState(() {
      _comicsPath = comicsPath;
    });

    if (comicsPath != null) {
      await Provider.of<ComicProvider>(context, listen: false).loadComics(comicsPath);
    }
  }

  Future<void> _selectComicsDirectory() async {
    final String? directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('comics_path', directoryPath);
      _loadComics();
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

  FolderNode? _findFolderByPath(String path, FolderNode folder) {
    if (folder.fullPath == path) {
      return folder;
    }

    for (final subfolder in folder.subfolders) {
      final found = _findFolderByPath(path, subfolder);
      if (found != null) return found;
    }

    return null;
  }

  // Add this method to handle back navigation
  void _navigateBack(ComicProvider comicProvider) {
    // Navigate to the parent directory
    final currentPath = comicProvider.currentPath;
    final parentPath = currentPath.split('/').sublist(0, currentPath.split('/').length - 1).join('/');
    
    if (parentPath.isNotEmpty && parentPath != currentPath) {
      comicProvider.navigateToFolder(parentPath);
    } else if (_comicsPath != null) {
      // If we can't determine parent, go to root
      comicProvider.navigateToFolder(_comicsPath!);
    }
  }
}