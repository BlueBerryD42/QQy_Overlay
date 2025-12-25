import 'package:flutter/material.dart';
import '../models/db/creator_model.dart';
import '../services/database_service.dart';
import '../repositories/creator_repository.dart';

class CreatorManagementScreen extends StatefulWidget {
  const CreatorManagementScreen({super.key});

  @override
  State<CreatorManagementScreen> createState() => _CreatorManagementScreenState();
}

class _CreatorManagementScreenState extends State<CreatorManagementScreen> {
  final DatabaseService _dbService = DatabaseService();
  late CreatorRepository _creatorRepository;
  bool _isInitialized = false;
  bool _isLoading = true;
  
  List<CreatorModel> _creators = [];
  String _searchQuery = '';
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
  }

  Future<void> _initializeRepositories() async {
    await _dbService.initializeDatabase();
    setState(() {
      _creatorRepository = CreatorRepository(_dbService);
      _isInitialized = true;
    });
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final creators = await _creatorRepository.getAllCreators();
      setState(() {
        _creators = creators;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading creators: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading creators: $e')),
        );
      }
    }
  }

  List<CreatorModel> get _filteredCreators {
    var filtered = _creators;
    
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((creator) =>
        creator.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (creator.role?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }
    
    if (_roleFilter != null && _roleFilter!.isNotEmpty) {
      filtered = filtered.where((creator) => creator.role == _roleFilter).toList();
    }
    
    return filtered;
  }

  List<String> get _availableRoles {
    final roles = _creators
        .where((c) => c.role != null && c.role!.isNotEmpty)
        .map((c) => c.role!)
        .toSet()
        .toList();
    roles.sort();
    return roles;
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
        await _creatorRepository.createCreator(creator);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Creator created successfully')),
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

  Future<void> _editCreator(CreatorModel creator) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditCreatorDialog(creator: creator),
    );
    
    if (result != null) {
      try {
        final updatedCreator = creator.copyWith(
          name: result['name'] as String?,
          role: result['role'] as String?,
          websiteUrl: result['website_url'] as String?,
          socialLink: result['social_link'] as String?,
        );
        await _creatorRepository.updateCreator(updatedCreator);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Creator updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating creator: $e')),
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
                  'Creator Management',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Search
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search creators...',
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
                // Role filter
                DropdownButton<String?>(
                  value: _roleFilter,
                  hint: const Text('All Roles'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All Roles')),
                    ..._availableRoles.map((role) => DropdownMenuItem<String?>(
                      value: role,
                      child: Text(role),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() => _roleFilter = value);
                  },
                ),
                const SizedBox(width: 16),
                // Create Creator button
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New Creator'),
                  onPressed: _createCreator,
                ),
              ],
            ),
          ),
          // Creators list
          Expanded(
            child: _filteredCreators.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _roleFilter != null
                              ? 'No creators found'
                              : 'No creators yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Create First Creator'),
                          onPressed: _createCreator,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredCreators.length,
                    itemBuilder: (context, index) {
                      final creator = _filteredCreators[index];
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                            child: Icon(
                              Icons.person,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          title: Text(creator.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (creator.role != null && creator.role!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Chip(
                                    label: Text(creator.role!),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              if (creator.websiteUrl != null || creator.socialLink != null) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    if (creator.websiteUrl != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.public, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            creator.websiteUrl!,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    if (creator.socialLink != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.link, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            creator.socialLink!,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editCreator(creator),
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

class _CreateCreatorDialog extends StatefulWidget {
  const _CreateCreatorDialog();

  @override
  State<_CreateCreatorDialog> createState() => _CreateCreatorDialogState();
}

class _CreateCreatorDialogState extends State<_CreateCreatorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _roleController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _socialLinkController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _websiteUrlController.dispose();
    _socialLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Creator'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Creator Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roleController,
                decoration: const InputDecoration(
                  labelText: 'Role (e.g., Artist, Author)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _websiteUrlController,
                decoration: const InputDecoration(
                  labelText: 'Website URL',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _socialLinkController,
                decoration: const InputDecoration(
                  labelText: 'Social Link',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
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
                'role': _roleController.text.trim().isEmpty 
                    ? null 
                    : _roleController.text.trim(),
                'website_url': _websiteUrlController.text.trim().isEmpty 
                    ? null 
                    : _websiteUrlController.text.trim(),
                'social_link': _socialLinkController.text.trim().isEmpty 
                    ? null 
                    : _socialLinkController.text.trim(),
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EditCreatorDialog extends StatefulWidget {
  final CreatorModel creator;

  const _EditCreatorDialog({required this.creator});

  @override
  State<_EditCreatorDialog> createState() => _EditCreatorDialogState();
}

class _EditCreatorDialogState extends State<_EditCreatorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _roleController;
  late TextEditingController _websiteUrlController;
  late TextEditingController _socialLinkController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.creator.name);
    _roleController = TextEditingController(text: widget.creator.role ?? '');
    _websiteUrlController = TextEditingController(text: widget.creator.websiteUrl ?? '');
    _socialLinkController = TextEditingController(text: widget.creator.socialLink ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _websiteUrlController.dispose();
    _socialLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Creator'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Creator Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _roleController,
                decoration: const InputDecoration(
                  labelText: 'Role (e.g., Artist, Author)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _websiteUrlController,
                decoration: const InputDecoration(
                  labelText: 'Website URL',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _socialLinkController,
                decoration: const InputDecoration(
                  labelText: 'Social Link',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
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
                'role': _roleController.text.trim().isEmpty 
                    ? null 
                    : _roleController.text.trim(),
                'website_url': _websiteUrlController.text.trim().isEmpty 
                    ? null 
                    : _websiteUrlController.text.trim(),
                'social_link': _socialLinkController.text.trim().isEmpty 
                    ? null 
                    : _socialLinkController.text.trim(),
              });
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}




