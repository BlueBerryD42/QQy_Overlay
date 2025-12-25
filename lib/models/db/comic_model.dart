class ComicModel {
  final int? comicId;
  final String title;
  final String? alternativeTitle;
  final String? description;
  final String managedPath;
  final String? coverImagePath;
  final int? coverPageId;
  final String status;
  final int? rating;
  final DateTime createdAt;
  final DateTime updatedAt;

  ComicModel({
    this.comicId,
    required this.title,
    this.alternativeTitle,
    this.description,
    required this.managedPath,
    this.coverImagePath,
    this.coverPageId,
    this.status = 'active',
    this.rating,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'comic_id': comicId,
      'title': title,
      'alternative_title': alternativeTitle,
      'description': description,
      'managed_path': managedPath,
      'cover_image_path': coverImagePath,
      'cover_page_id': coverPageId,
      'status': status,
      'rating': rating,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ComicModel.fromMap(Map<String, dynamic> map) {
    final title = map['title'] as String?;
    final managedPath = map['managed_path'] as String?;
    
    if (title == null) throw ArgumentError('title is required');
    if (managedPath == null) throw ArgumentError('managed_path is required');
    
    return ComicModel(
      comicId: (map['comic_id'] as num?)?.toInt(),
      title: title,
      alternativeTitle: map['alternative_title'] as String?,
      description: map['description'] as String?,
      managedPath: managedPath,
      coverImagePath: map['cover_image_path'] as String?,
      coverPageId: (map['cover_page_id'] as num?)?.toInt(),
      status: map['status'] as String? ?? 'active',
      rating: (map['rating'] as num?)?.toInt(),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
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

  ComicModel copyWith({
    int? comicId,
    String? title,
    String? alternativeTitle,
    String? description,
    String? managedPath,
    String? coverImagePath,
    int? coverPageId,
    String? status,
    int? rating,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ComicModel(
      comicId: comicId ?? this.comicId,
      title: title ?? this.title,
      alternativeTitle: alternativeTitle ?? this.alternativeTitle,
      description: description ?? this.description,
      managedPath: managedPath ?? this.managedPath,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      coverPageId: coverPageId ?? this.coverPageId,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

