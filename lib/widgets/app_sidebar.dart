import 'package:flutter/material.dart';

enum NavigationItem {
  home,
  tags,
  creators,
  favorites,
  webview,
  settings,
}

class AppSidebar extends StatelessWidget {
  final NavigationItem selectedItem;
  final Function(NavigationItem) onItemSelected;
  final double width;

  const AppSidebar({
    super.key,
    required this.selectedItem,
    required this.onItemSelected,
    this.width = 240,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: width,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200],
      child: Column(
        children: [
          // App logo/title area - matches top bar height exactly
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
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
                Icon(
                  Icons.menu_book,
                  color: theme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'QRganize',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Navigation items - takes remaining space
          Expanded(
            child: Column(
              children: [
                // Top navigation items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildNavItem(
                        context: context,
                        icon: Icons.home,
                        label: 'Home',
                        item: NavigationItem.home,
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.label,
                        label: 'Tags',
                        item: NavigationItem.tags,
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.person,
                        label: 'Creators',
                        item: NavigationItem.creators,
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.favorite,
                        label: 'Favorites',
                        item: NavigationItem.favorites,
                      ),
                      _buildNavItem(
                        context: context,
                        icon: Icons.web,
                        label: 'Grok AI',
                        item: NavigationItem.webview,
                      ),
                    ],
                  ),
                ),
                
                // Settings at the bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildNavItem(
                    context: context,
                    icon: Icons.settings,
                    label: 'Settings',
                    item: NavigationItem.settings,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required NavigationItem item,
  }) {
    final theme = Theme.of(context);
    final isSelected = selectedItem == item;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => onItemSelected(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.grey[800] : Colors.grey[300])
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? theme.primaryColor
                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? theme.primaryColor
                    : (isDark ? Colors.grey[300] : Colors.grey[900]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

