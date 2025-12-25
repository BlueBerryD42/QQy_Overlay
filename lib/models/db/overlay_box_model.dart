class OverlayBoxModel {
  final int? overlayId;
  final int pageId;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final int zIndex;
  final String? originalText;
  final String? translatedText;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  OverlayBoxModel({
    this.overlayId,
    required this.pageId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.zIndex = 0,
    this.originalText,
    this.translatedText,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'overlay_id': overlayId,
      'page_id': pageId,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'z_index': zIndex,
      'original_text': originalText,
      'translated_text': translatedText,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory OverlayBoxModel.fromMap(Map<String, dynamic> map) {
    final pageId = (map['page_id'] as num?)?.toInt();
    final x = (map['x'] as num?)?.toDouble();
    final y = (map['y'] as num?)?.toDouble();
    final width = (map['width'] as num?)?.toDouble();
    final height = (map['height'] as num?)?.toDouble();
    
    if (pageId == null) throw ArgumentError('page_id is required');
    if (x == null) throw ArgumentError('x is required');
    if (y == null) throw ArgumentError('y is required');
    if (width == null) throw ArgumentError('width is required');
    if (height == null) throw ArgumentError('height is required');
    
    return OverlayBoxModel(
      overlayId: (map['overlay_id'] as num?)?.toInt(),
      pageId: pageId,
      x: x,
      y: y,
      width: width,
      height: height,
      rotation: (map['rotation'] as num?)?.toDouble() ?? 0,
      zIndex: (map['z_index'] as num?)?.toInt() ?? 0,
      originalText: map['original_text'] as String?,
      translatedText: map['translated_text'] as String?,
      isVerified: map['is_verified'] as bool? ?? false,
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

  OverlayBoxModel copyWith({
    int? overlayId,
    int? pageId,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    String? originalText,
    String? translatedText,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OverlayBoxModel(
      overlayId: overlayId ?? this.overlayId,
      pageId: pageId ?? this.pageId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      zIndex: zIndex ?? this.zIndex,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

