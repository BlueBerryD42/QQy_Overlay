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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<CreatorModel> _searchSuggestions = [];
  bool _showSuggestions = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadCreators();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _searchFocusNode.hasFocus && _searchQuery.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _searchSuggestions = [];
        _showSuggestions = false;
      } else {
        _searchSuggestions = _allCreators.where((creator) {
          final nameMatch = creator.name.toLowerCase().contains(query);
          final roleMatch = creator.role?.toLowerCase().contains(query) ?? false;
          return nameMatch || roleMatch;
        }).take(10).toList(); // Limit to 10 suggestions
        _showSuggestions = _searchFocusNode.hasFocus && _searchSuggestions.isNotEmpty;
      }
    });
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

  void _selectCreator(CreatorModel creator) {
    if (creator.creatorId == null) return;
    
    final newSelection = List<int>.from(widget.selectedCreatorIds);
    if (!newSelection.contains(creator.creatorId)) {
      newSelection.add(creator.creatorId!);
      widget.onSelectionChanged(newSelection);
    }
    
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _showSuggestions = false;
    });
  }

  void _removeCreator(int creatorId) {
    final newSelection = List<int>.from(widget.selectedCreatorIds);
    newSelection.remove(creatorId);
    widget.onSelectionChanged(newSelection);
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
        
        // Clear search and show success
        _searchController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Creator created and added!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating creator: $e')),
          );
        }
      }
    }
  }

  List<CreatorModel> get _selectedCreators {
    return _allCreators.where((c) => 
      c.creatorId != null && widget.selectedCreatorIds.contains(c.creatorId)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedCreators = _selectedCreators;

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
        
        // Selected creators (always visible, removable)
        if (selectedCreators.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedCreators.map((creator) => _buildSelectedCreatorChip(creator)).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        // Autocomplete search field
        Stack(
          children: [
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search creators... (${_allCreators.length} total)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
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
              onSubmitted: (value) {
                // If exact match found, select it
                final match = _allCreators.firstWhere(
                  (c) => c.name.toLowerCase() == value.toLowerCase(),
                  orElse: () => CreatorModel(name: '', createdAt: DateTime.now()),
                );
                if (match.creatorId != null) {
                  _selectCreator(match);
                } else {
                  // No match - offer to create
                  _createCreator();
                }
              },
            ),
            
            // Suggestions dropdown
            if (_showSuggestions && _searchSuggestions.isNotEmpty)
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade900
                      : Colors.white,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.grey.shade600,
                        width: 1,
                      ),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchSuggestions.length,
                      itemBuilder: (context, index) {
                        final creator = _searchSuggestions[index];
                        final isSelected = creator.creatorId != null &&
                            widget.selectedCreatorIds.contains(creator.creatorId);
                        
                        return ListTile(
                          dense: true,
                          title: Text(
                            creator.name,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected 
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                          subtitle: creator.role != null
                              ? Text(
                                  creator.role!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                )
                              : null,
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                )
                              : null,
                          onTap: isSelected
                              ? null
                              : () => _selectCreator(creator),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSelectedCreatorChip(CreatorModel creator) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            creator.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (creator.role != null) ...[
            const SizedBox(width: 4),
            Text(
              '(${creator.role})',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      backgroundColor: Theme.of(context).primaryColor,
      deleteIcon: const Icon(
        Icons.close,
        size: 18,
        color: Colors.white,
      ),
      onDeleted: () => _removeCreator(creator.creatorId!),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
