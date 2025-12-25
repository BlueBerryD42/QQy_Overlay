import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';

class ImageMetadata {
  final int width;
  final int height;
  final int? dpi;
  final String? colorProfile;
  final String imageHash;
  final int fileSizeBytes;
  final String fileExtension;

  ImageMetadata({
    required this.width,
    required this.height,
    this.dpi,
    this.colorProfile,
    required this.imageHash,
    required this.fileSizeBytes,
    required this.fileExtension,
  });
}

class MetadataExtractor {
  Future<ImageMetadata> extractMetadata(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final decoder = img.findDecoderForData(bytes);
    
    if (decoder == null) {
      throw Exception('Unsupported image format: ${imageFile.path}');
    }

    final image = decoder.decode(bytes);
    if (image == null) {
      throw Exception('Failed to decode image: ${imageFile.path}');
    }

    // Get file size
    final fileSize = await imageFile.length();
    
    // Get file extension
    final extension = imageFile.path.split('.').last.toLowerCase();
    
    // Generate hash
    final hash = _generateHash(bytes);
    
    // Extract DPI (if available in EXIF)
    int? dpi;
    // Note: The image package may not always have DPI in EXIF
    // This is a placeholder - you may need to use a different library for full EXIF support
    
    // Default DPI if not found
    dpi ??= 72; // Common default
    
    // Color profile (simplified - would need more sophisticated extraction)
    String? colorProfile;
    final formatName = image.format.toString().toLowerCase();
    if (formatName.contains('jpeg') || formatName.contains('png')) {
      colorProfile = 'sRGB'; // Default assumption
    }

    return ImageMetadata(
      width: image.width,
      height: image.height,
      dpi: dpi,
      colorProfile: colorProfile,
      imageHash: hash,
      fileSizeBytes: fileSize,
      fileExtension: extension,
    );
  }

  String _generateHash(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> generateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    return _generateHash(bytes);
  }

  Future<bool> isImageFile(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoder = img.findDecoderForData(bytes);
      return decoder != null;
    } catch (e) {
      return false;
    }
  }

  Future<Uint8List?> generateThumbnail(
    File imageFile, {
    int maxWidth = 300,
    int maxHeight = 300,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoder = img.findDecoderForData(bytes);
      
      if (decoder == null) return null;
      
      final image = decoder.decode(bytes);
      if (image == null) return null;
      
      // Calculate thumbnail dimensions
      final aspectRatio = image.width / image.height;
      int thumbWidth = maxWidth;
      int thumbHeight = maxHeight;
      
      if (aspectRatio > 1) {
        thumbHeight = (maxWidth / aspectRatio).round();
      } else {
        thumbWidth = (maxHeight * aspectRatio).round();
      }
      
      // Resize image
      final thumbnail = img.copyResize(
        image,
        width: thumbWidth,
        height: thumbHeight,
        interpolation: img.Interpolation.linear,
      );
      
      // Encode as JPEG
      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 85);
      return Uint8List.fromList(thumbnailBytes);
    } catch (e) {
      return null;
    }
  }

  Future<String?> saveThumbnail(
    File imageFile,
    String thumbnailPath, {
    int maxWidth = 300,
    int maxHeight = 300,
  }) async {
    final thumbnailBytes = await generateThumbnail(
      imageFile,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    
    if (thumbnailBytes == null) return null;
    
    final thumbnailFile = File(thumbnailPath);
    await thumbnailFile.writeAsBytes(thumbnailBytes);
    
    return thumbnailPath;
  }
}

