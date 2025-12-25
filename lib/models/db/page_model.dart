class PageModel {
  final int? pageId;
  final int comicId;
  final int pageNumber;
  final String storagePath;
  final String fileName;
  final String? fileExtension;
  final int? fileSizeBytes;
  final int? width;
  final int? height;
  final int? dpi;
  final String? colorProfile;
  final String? imageHash;
  final String? thumbnailPath;
  final DateTime createdAt;

  PageModel({
    this.pageId,
    required this.comicId,
    required this.pageNumber,
    required this.storagePath,
    required this.fileName,
    this.fileExtension,
    this.fileSizeBytes,
    this.width,
    this.height,
    this.dpi,
    this.colorProfile,
    this.imageHash,
    this.thumbnailPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'page_id': pageId,
      'comic_id': comicId,
      'page_number': pageNumber,
      'storage_path': storagePath,
      'file_name': fileName,
      'file_extension': fileExtension,
      'file_size_bytes': fileSizeBytes,
      'width': width,
      'height': height,
      'dpi': dpi,
      'color_profile': colorProfile,
      'image_hash': imageHash,
      'thumbnail_path': thumbnailPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PageModel.fromMap(Map<String, dynamic> map) {
    final comicId = (map['comic_id'] as num?)?.toInt();
    final pageNumber = (map['page_number'] as num?)?.toInt();
    final storagePath = map['storage_path'] as String?;
    final fileName = map['file_name'] as String?;
    
    if (comicId == null) throw ArgumentError('comic_id is required');
    if (pageNumber == null) throw ArgumentError('page_number is required');
    if (storagePath == null) throw ArgumentError('storage_path is required');
    if (fileName == null) throw ArgumentError('file_name is required');
    
    return PageModel(
      pageId: (map['page_id'] as num?)?.toInt(),
      comicId: comicId,
      pageNumber: pageNumber,
      storagePath: storagePath,
      fileName: fileName,
      fileExtension: map['file_extension'] as String?,
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt(),
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      dpi: (map['dpi'] as num?)?.toInt(),
      colorProfile: map['color_profile'] as String?,
      imageHash: map['image_hash'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
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

  PageModel copyWith({
    int? pageId,
    int? comicId,
    int? pageNumber,
    String? storagePath,
    String? fileName,
    String? fileExtension,
    int? fileSizeBytes,
    int? width,
    int? height,
    int? dpi,
    String? colorProfile,
    String? imageHash,
    String? thumbnailPath,
    DateTime? createdAt,
  }) {
    return PageModel(
      pageId: pageId ?? this.pageId,
      comicId: comicId ?? this.comicId,
      pageNumber: pageNumber ?? this.pageNumber,
      storagePath: storagePath ?? this.storagePath,
      fileName: fileName ?? this.fileName,
      fileExtension: fileExtension ?? this.fileExtension,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      dpi: dpi ?? this.dpi,
      colorProfile: colorProfile ?? this.colorProfile,
      imageHash: imageHash ?? this.imageHash,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

