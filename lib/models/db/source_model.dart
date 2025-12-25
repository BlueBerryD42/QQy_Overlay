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

class SourceModel {
  final int? sourceId;
  final String? platform;
  final String? sourceUrl;
  final String? authorHandle;
  final String? postId;
  final String? description;
  final DateTime discoveredAt;
  final bool isPrimary;

  SourceModel({
    this.sourceId,
    this.platform,
    this.sourceUrl,
    this.authorHandle,
    this.postId,
    this.description,
    required this.discoveredAt,
    this.isPrimary = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'source_id': sourceId,
      'platform': platform,
      'source_url': sourceUrl,
      'author_handle': authorHandle,
      'post_id': postId,
      'description': description,
      'discovered_at': discoveredAt.toIso8601String(),
      'is_primary': isPrimary,
    };
  }

  factory SourceModel.fromMap(Map<String, dynamic> map) {
    return SourceModel(
      sourceId: (map['source_id'] as num?)?.toInt(),
      platform: map['platform'] as String?,
      sourceUrl: map['source_url'] as String?,
      authorHandle: map['author_handle'] as String?,
      postId: map['post_id'] as String?,
      description: map['description'] as String?,
      discoveredAt: _parseDateTime(map['discovered_at']),
      isPrimary: map['is_primary'] as bool? ?? false,
    );
  }
}

