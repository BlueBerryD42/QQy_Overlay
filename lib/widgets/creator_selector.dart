import 'package:flutter/material.dart';
import '../models/db/creator_model.dart';
import '../repositories/creator_repository.dart';

class CreatorSelector extends StatefulWidget {
  final CreatorRepository creatorRepository;
  final List<int> selectedCreatorIds;
  final Function(List<int>) onSelectionChanged;

  const CreatorSelector({
    super.key,
    required this.creatorRepository,
    required this.selectedCreatorIds,
    required this.onSelectionChanged,
  });

  @override
  State<CreatorSelector> createState() => _CreatorSelectorState();
}

class _CreatorSelectorState extends State<CreatorSelector> {
  List<CreatorModel> _allCreators = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCreators();
  }

  Future<void> _loadCreators() async {
    setState(() => _isLoading = true);
    
    try {
      final creators = await widget.creatorRepository.getAllCreators();
      setState(() {
        _allCreators = creators;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading creators: $e')),
        );
      }
    }
  }

  Future<void> _createCreator() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CreateCreatorDialog(),
    );

    if (result != null) {
      try {
        final creator = CreatorModel(
          name: result['name'] as String,
          role: result['role'] as String?,
          websiteUrl: result['website_url'] as String?,
          socialLink: result['social_link'] as String?,
          createdAt: DateTime.now(),
        );

        final creatorId = await widget.creatorRepository.createCreator(creator);
        await _loadCreators();
        
        // Auto-select the newly created creator
        final newSelection = List<int>.from(widget.selectedCreatorIds)..add(creatorId);
        widget.onSelectionChanged(newSelection);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating creator: $e')),
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
              'Creators',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _createCreator,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Creator'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allCreators.map((creator) => _buildCreatorChip(creator)).toList(),
        ),
      ],
    );
  }

  Widget _buildCreatorChip(CreatorModel creator) {
    final isSelected = creator.creatorId != null && 
        widget.selectedCreatorIds.contains(creator.creatorId);
    
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(creator.name),
          if (creator.role != null) ...[
            const SizedBox(width: 4),
            Text(
              '(${creator.role})',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        final newSelection = List<int>.from(widget.selectedCreatorIds);
        if (selected && creator.creatorId != null) {
          newSelection.add(creator.creatorId!);
        } else if (!selected && creator.creatorId != null) {
          newSelection.remove(creator.creatorId!);
        }
        widget.onSelectionChanged(newSelection);
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }
}

class _CreateCreatorDialog extends StatefulWidget {
  const _CreateCreatorDialog();

  @override
  State<_CreateCreatorDialog> createState() => _CreateCreatorDialogState();
}

class _CreateCreatorDialogState extends State<_CreateCreatorDialog> {
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _websiteController = TextEditingController();
  final _socialController = TextEditingController();
  bool _isNameValid = false;

  @override
  void initState() {
    super.initState();
    // Add listener to update button state when name changes
    _nameController.addListener(() {
      setState(() {
        _isNameValid = _nameController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _websiteController.dispose();
    _socialController.dispose();
    super.dispose();
  }

  void _handleCreate() {
    if (!_isNameValid) return;
    
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'role': _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
      'website_url': _websiteController.text.trim().isEmpty 
          ? null 
          : _websiteController.text.trim(),
      'social_link': _socialController.text.trim().isEmpty 
          ? null 
          : _socialController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Creator'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Creator Name *',
                hintText: 'Enter creator name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Role (optional)',
                hintText: 'e.g., Author, Artist, Translator',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website URL (optional)',
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _socialController,
              decoration: const InputDecoration(
                labelText: 'Social Link (optional)',
                hintText: 'Twitter, Instagram, etc.',
              ),
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
          onPressed: _isNameValid ? _handleCreate : null,
          child: const Text('Create'),
        ),
      ],
    );
  }
}




