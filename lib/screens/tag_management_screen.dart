import 'package:flutter/material.dart';
import '../models/db/tag_model.dart';
import '../services/database_service.dart';
import '../repositories/tag_repository.dart';

class TagManagementScreen extends StatefulWidget {
  const TagManagementScreen({super.key});

  @override
  State<TagManagementScreen> createState() => _TagManagementScreenState();
}

class _TagManagementScreenState extends State<TagManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  late TagRepository _tagRepository;
  bool _isInitialized = false;
  bool _isLoading = true;
  
  List<TagModel> _tags = [];
  List<TagGroupModel> _tagGroups = [];
  String _searchQuery = '';
  int? _selectedGroupFilter;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
  }

  Future<void> _initializeRepositories() async {
    await _dbService.initializeDatabase();
    setState(() {
      _tagRepository = TagRepository(_dbService);
      _isInitialized = true;
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final tags = await _tagRepository.getAllTags();
      final groups = await _tagRepository.getAllTagGroups();
      setState(() {
        _tags = tags;
        _tagGroups = groups;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading tags: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tags: $e')),
        );
      }
    }
  }

  List<TagModel> get _filteredTags {
    var filtered = _tags;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((tag) =>
        tag.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (tag.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    
    if (_selectedGroupFilter != null) {
      filtered = filtered.where((tag) => tag.groupId == _selectedGroupFilter).toList();
    }
    
    return filtered;
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
        await _tagRepository.createTag(tag);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tag created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating tag: $e')),
          );
        }
      }
    }
  }

  Future<void> _createTagGroup() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _CreateTagGroupDialog(),
    );
    
    if (result != null && result.isNotEmpty) {
      try {
        final group = TagGroupModel(
          name: result,
          createdAt: DateTime.now(),
        );
        await _tagRepository.createTagGroup(group);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tag group created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating tag group: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Tag Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Search
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tags...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Group filter
                DropdownButton<int?>(
                  value: _selectedGroupFilter,
                  hint: const Text('All Groups'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All Groups')),
                    ..._tagGroups.map((group) => DropdownMenuItem<int?>(
                      value: group.groupId,
                      child: Text(group.name),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedGroupFilter = value);
                  },
                ),
                const SizedBox(width: 16),
                // Create Tag Group button
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder),
                  label: const Text('New Group'),
                  onPressed: _createTagGroup,
                ),
                const SizedBox(width: 8),
                // Create Tag button
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Tag'),
                  onPressed: _createTag,
                ),
              ],
            ),
          ),
          // Tags list
          Expanded(
            child: _filteredTags.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.label_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _selectedGroupFilter != null
                              ? 'No tags found'
                              : 'No tags yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Create First Tag'),
                          onPressed: _createTag,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredTags.length,
                    itemBuilder: (context, index) {
                      final tag = _filteredTags[index];
                      final group = _tagGroups.firstWhere(
                        (g) => g.groupId == tag.groupId,
                        orElse: () => TagGroupModel(groupId: null, name: 'No Group', createdAt: DateTime.now()),
                      );
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tag.isSensitive 
                                ? Colors.red.withOpacity(0.2)
                                : Theme.of(context).primaryColor.withOpacity(0.2),
                            child: Icon(
                              tag.isSensitive ? Icons.warning : Icons.label,
                              color: tag.isSensitive 
                                  ? Colors.red
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                          title: Text(tag.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (tag.description != null && tag.description!.isNotEmpty)
                                Text(tag.description!),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(group.name),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  if (tag.isSensitive) ...[
                                    const SizedBox(width: 8),
                                    Chip(
                                      label: const Text('Sensitive'),
                                      backgroundColor: Colors.red.withOpacity(0.2),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              // TODO: Implement edit
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Edit functionality coming soon')),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dbService.dispose();
    super.dispose();
  }
}

class _CreateTagDialog extends StatefulWidget {
  final List<TagGroupModel> tagGroups;

  const _CreateTagDialog({required this.tagGroups});

  @override
  State<_CreateTagDialog> createState() => _CreateTagDialogState();
}

class _CreateTagDialogState extends State<_CreateTagDialog> {
  final _formKey = GlobalKey<FormState>();
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
      title: const Text('Create Tag'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Tag Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: _selectedGroupId,
                decoration: const InputDecoration(
                  labelText: 'Tag Group',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('No Group')),
                  ...widget.tagGroups.map((group) => DropdownMenuItem<int?>(
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
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'name': _nameController.text.trim(),
                'description': _descriptionController.text.trim().isEmpty 
                    ? null 
                    : _descriptionController.text.trim(),
                'group_id': _selectedGroupId,
                'is_sensitive': _isSensitive,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _CreateTagGroupDialog extends StatefulWidget {
  @override
  State<_CreateTagGroupDialog> createState() => _CreateTagGroupDialogState();
}

class _CreateTagGroupDialogState extends State<_CreateTagGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Tag Group'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Group Name *',
            border: OutlineInputBorder(),
          ),
          validator: (value) => value?.isEmpty == true ? 'Required' : null,
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_nameController.text.trim());
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

