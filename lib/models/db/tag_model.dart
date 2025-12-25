DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (e) {
      return DateTime.now();
    }
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  return DateTime.now();
}

class TagGroupModel {
  final int? groupId;
  final String name;
  final DateTime createdAt;

  TagGroupModel({
    this.groupId,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'name': name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TagGroupModel.fromMap(Map<String, dynamic> map) {
    final name = map['name'] as String?;
    if (name == null) throw ArgumentError('name is required');
    
    return TagGroupModel(
      groupId: (map['group_id'] as num?)?.toInt(),
      name: name,
      createdAt: _parseDateTime(map['created_at']),
    );
  }
}

class TagModel {
  final int? tagId;
  final int? groupId;
  final String name;
  final String? description;
  final bool isSensitive;
  final DateTime createdAt;

  TagModel({
    this.tagId,
    this.groupId,
    required this.name,
    this.description,
    this.isSensitive = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'tag_id': tagId,
      'group_id': groupId,
      'name': name,
      'description': description,
      'is_sensitive': isSensitive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TagModel.fromMap(Map<String, dynamic> map) {
    final name = map['name'] as String?;
    if (name == null) throw ArgumentError('name is required');
    
    return TagModel(
      tagId: (map['tag_id'] as num?)?.toInt(),
      groupId: (map['group_id'] as num?)?.toInt(),
      name: name,
      description: map['description'] as String?,
      isSensitive: map['is_sensitive'] as bool? ?? false,
      createdAt: _parseDateTime(map['created_at']),
    );
  }
}

