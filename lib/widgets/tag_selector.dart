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

  @override
  void initState() {
    super.initState();
    _loadTags();
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _buildTagChips(),
        ),
      ],
    );
  }

  List<Widget> _buildTagChips() {
    final chips = <Widget>[];

    // Add ungrouped tags
    final ungroupedTags = _tagsByGroup[0] ?? [];
    for (final tag in ungroupedTags) {
      chips.add(_buildTagChip(tag));
    }

    // Add grouped tags
    for (final group in _tagGroups) {
      final groupTags = _tagsByGroup[group.groupId] ?? [];
      if (groupTags.isEmpty) continue;

      chips.add(
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                group.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: groupTags.map((tag) => _buildTagChip(tag)).toList(),
              ),
            ],
          ),
        ),
      );
    }

    return chips;
  }

  Widget _buildTagChip(TagModel tag) {
    final isSelected = widget.selectedTagIds.contains(tag.tagId);
    
    return FilterChip(
      label: Text(tag.name),
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
          ? Colors.red.shade100 
          : Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: tag.isSensitive 
          ? Colors.red.shade700 
          : Theme.of(context).primaryColor,
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

