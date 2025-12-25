import 'package:flutter/material.dart';
import '../models/db/tag_model.dart';
import '../repositories/tag_repository.dart';

class TagSelector extends StatefulWidget {
  final TagRepository tagRepository;
  final List<int> selectedTagIds;
  final Function(List<int>) onSelectionChanged;

  const TagSelector({
    super.key,
    required this.tagRepository,
    required this.selectedTagIds,
    required this.onSelectionChanged,
  });

  @override
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  List<TagModel> _allTags = [];
  List<TagGroupModel> _tagGroups = [];
  bool _isLoading = true;
  final Map<int, List<TagModel>> _tagsByGroup = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final int _maxVisibleTags = 10; // Show max 10 tags, rest via search

  @override
  void initState() {
    super.initState();
    _loadTags();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    setState(() => _isLoading = true);
    
    try {
      final tags = await widget.tagRepository.getAllTags();
      final groups = await widget.tagRepository.getAllTagGroups();
      
      final tagsByGroup = <int, List<TagModel>>{};
      for (final tag in tags) {
        final groupId = tag.groupId ?? 0;
        tagsByGroup.putIfAbsent(groupId, () => []).add(tag);
      }
      
      setState(() {
        _allTags = tags;
        _tagGroups = groups;
        _tagsByGroup.clear();
        _tagsByGroup.addAll(tagsByGroup);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tags: $e')),
        );
      }
    }
  }

  List<TagModel> get _filteredTags {
    if (_searchQuery.isEmpty) {
      // Show selected tags first, then unselected (limited)
      final selected = _allTags.where((t) => 
        t.tagId != null && widget.selectedTagIds.contains(t.tagId)).toList();
      final unselected = _allTags.where((t) => 
        t.tagId == null || !widget.selectedTagIds.contains(t.tagId)).toList();
      
      return [
        ...selected,
        ...unselected.take(_maxVisibleTags - selected.length),
      ];
    } else {
      // Filter by search query
      return _allTags.where((tag) => 
        tag.name.toLowerCase().contains(_searchQuery)
      ).toList();
    }
  }

  int get _hiddenTagsCount {
    if (_searchQuery.isNotEmpty) return 0;
    final visible = _filteredTags.length;
    final total = _allTags.length;
    return total > visible ? total - visible : 0;
  }

  Future<void> _createTag() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateTagDialog(tagGroups: _tagGroups),
    );

    if (result != null) {
      try {
        final tag = TagModel(
          groupId: result['group_id'] as int?,
          name: result['name'] as String,
          description: result['description'] as String?,
          isSensitive: result['is_sensitive'] as bool? ?? false,
          createdAt: DateTime.now(),
        );

        final tagId = await widget.tagRepository.createTag(tag);
        await _loadTags();
        
        // Auto-select the newly created tag
        final newSelection = List<int>.from(widget.selectedTagIds)..add(tagId);
        widget.onSelectionChanged(newSelection);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating tag: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedTags = _allTags.where((t) => 
      t.tagId != null && widget.selectedTagIds.contains(t.tagId)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tags',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _createTag,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Tag'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Selected tags (always visible, removable)
        if (selectedTags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedTags.map((tag) => _buildSelectedTagChip(tag)).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: _searchQuery.isEmpty 
                ? 'Search tags... (${_allTags.length} total)'
                : 'Searching...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                : null,
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade800
                : Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey.shade600,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey.shade600,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Available tags (filtered)
        if (_filteredTags.isNotEmpty || _searchQuery.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._filteredTags.where((tag) => 
                tag.tagId == null || !widget.selectedTagIds.contains(tag.tagId)
              ).map((tag) => _buildTagChip(tag)),
            ],
          ),
        
        // Show "X more tags" indicator
        if (_hiddenTagsCount > 0 && _searchQuery.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: () {
                // Focus search to show all tags
                FocusScope.of(context).requestFocus(FocusNode());
                _searchController.clear();
                _searchController.text = ' '; // Trigger search
                _searchController.clear();
              },
              icon: const Icon(Icons.expand_more),
              label: Text('$_hiddenTagsCount more tags (use search to find)'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade400,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectedTagChip(TagModel tag) {
    return Chip(
      label: Text(
        tag.name,
        style: TextStyle(
          color: tag.isSensitive ? Colors.red.shade100 : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: tag.isSensitive 
          ? Colors.red.shade700.withOpacity(0.8)
          : Theme.of(context).primaryColor,
      deleteIcon: Icon(
        Icons.close,
        size: 18,
        color: tag.isSensitive ? Colors.red.shade100 : Colors.white,
      ),
      onDeleted: () {
        final newSelection = List<int>.from(widget.selectedTagIds);
        if (tag.tagId != null) {
          newSelection.remove(tag.tagId!);
        }
        widget.onSelectionChanged(newSelection);
      },
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  Widget _buildTagChip(TagModel tag) {
    final isSelected = widget.selectedTagIds.contains(tag.tagId);
    
    return FilterChip(
      label: Text(
        tag.name,
        style: TextStyle(
          color: isSelected 
              ? (tag.isSensitive ? Colors.red.shade100 : Colors.white)
              : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        final newSelection = List<int>.from(widget.selectedTagIds);
        if (selected) {
          if (tag.tagId != null) {
            newSelection.add(tag.tagId!);
          }
        } else {
          if (tag.tagId != null) {
            newSelection.remove(tag.tagId!);
          }
        }
        widget.onSelectionChanged(newSelection);
      },
      selectedColor: tag.isSensitive 
          ? Colors.red.shade700.withOpacity(0.8)
          : Theme.of(context).primaryColor,
      checkmarkColor: tag.isSensitive 
          ? Colors.red.shade100
          : Colors.white,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey.shade800
          : Colors.grey.shade200,
      side: BorderSide(
        color: isSelected
            ? (tag.isSensitive ? Colors.red.shade400 : Theme.of(context).primaryColor)
            : Colors.grey.shade600,
        width: isSelected ? 2 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}

class _CreateTagDialog extends StatefulWidget {
  final List<TagGroupModel> tagGroups;

  const _CreateTagDialog({required this.tagGroups});

  @override
  State<_CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<_CreateTagDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  int? _selectedGroupId;
  bool _isSensitive = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Tag'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tag Name',
                hintText: 'Enter tag name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Enter description',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _selectedGroupId,
              decoration: const InputDecoration(
                labelText: 'Tag Group (optional)',
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text('No Group'),
                ),
                ...widget.tagGroups.map((group) => DropdownMenuItem<int>(
                  value: group.groupId,
                  child: Text(group.name),
                )),
              ],
              onChanged: (value) => setState(() => _selectedGroupId = value),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Sensitive Content'),
              value: _isSensitive,
              onChanged: (value) => setState(() => _isSensitive = value ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _nameController.text.isEmpty
              ? null
              : () => Navigator.pop(context, {
                    'name': _nameController.text,
                    'description': _descriptionController.text.isEmpty
                        ? null
                        : _descriptionController.text,
                    'group_id': _selectedGroupId,
                    'is_sensitive': _isSensitive,
                  }),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
