class CreatorModel {
  final int? creatorId;
  final String name;
  final String? role;
  final String? websiteUrl;
  final String? socialLink;
  final DateTime createdAt;

  CreatorModel({
    this.creatorId,
    required this.name,
    this.role,
    this.websiteUrl,
    this.socialLink,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'creator_id': creatorId,
      'name': name,
      'role': role,
      'website_url': websiteUrl,
      'social_link': socialLink,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CreatorModel.fromMap(Map<String, dynamic> map) {
    final name = map['name'] as String?;
    if (name == null) throw ArgumentError('name is required');
    
    return CreatorModel(
      creatorId: (map['creator_id'] as num?)?.toInt(),
      name: name,
      role: map['role'] as String?,
      websiteUrl: map['website_url'] as String?,
      socialLink: map['social_link'] as String?,
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
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

  CreatorModel copyWith({
    int? creatorId,
    String? name,
    String? role,
    String? websiteUrl,
    String? socialLink,
    DateTime? createdAt,
  }) {
    return CreatorModel(
      creatorId: creatorId ?? this.creatorId,
      name: name ?? this.name,
      role: role ?? this.role,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      socialLink: socialLink ?? this.socialLink,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

