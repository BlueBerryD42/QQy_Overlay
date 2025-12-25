import 'package:flutter/material.dart';

import '../models/translation.dart';

class RectanglePainter extends CustomPainter {
  final List<Translation> translations;
  final Rect? currentRect;
  final int? selectedBoxIndex;
  final int? hoveredBoxIndex;
  final Size imageSize; // Original image size
  final Size? displayedImageSize; // Size the image is displayed at
  final Offset? imageOffset; // Position where the image starts on screen
  final bool showText;
  final bool isEditMode;
  final Matrix4? transformMatrix; // Zoom/Pan transformation matrix

  RectanglePainter({
    required this.translations, 
    this.currentRect, 
    this.selectedBoxIndex, 
    this.hoveredBoxIndex, 
    required this.imageSize,
    this.displayedImageSize,
    this.imageOffset,
    this.showText = true,
    this.isEditMode = false,
    this.transformMatrix,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Don't draw anything if we don't have image positioning info
    if (displayedImageSize == null || imageOffset == null) return;

    // Apply transformation if zoom/pan is active
    if (transformMatrix != null) {
      canvas.save();
      canvas.transform(transformMatrix!.storage);
    }

    final paint = Paint()
      ..color = Colors.yellow.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final selectedPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final hoverPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final selectedBorderPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final hoverBorderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Convert relative coordinates to absolute screen coordinates
    Rect toScreenRect(Translation t) {
      return Rect.fromLTRB(
        imageOffset!.dx + (t.left * displayedImageSize!.width),
        imageOffset!.dy + (t.top * displayedImageSize!.height),
        imageOffset!.dx + (t.right * displayedImageSize!.width),
        imageOffset!.dy + (t.bottom * displayedImageSize!.height),
      );
    }

    // Draw existing translation boxes
    for (int i = 0; i < translations.length; i++) {
      final translation = translations[i];
      final screenRect = toScreenRect(translation);
      
      // Choose paint based on state
      Paint rectPaint;
      if (i == selectedBoxIndex) {
        rectPaint = selectedPaint;
      } else if (i == hoveredBoxIndex) {
        rectPaint = hoverPaint;
      } else {
        rectPaint = paint;
      }
      
      canvas.drawRect(screenRect, rectPaint);

      // Draw borders
      if (i == selectedBoxIndex) {
        canvas.drawRect(screenRect, selectedBorderPaint);
      } else if (i == hoveredBoxIndex) {
        canvas.drawRect(screenRect, hoverBorderPaint);
      }

      // Draw text if in view mode or if box is selected/hovered
      if (showText && (i == selectedBoxIndex || i == hoveredBoxIndex)) {
        _drawText(canvas, screenRect, translation.text);
      }

      // Draw resize handles for selected box
      if (i == selectedBoxIndex) {
        final handlePaint = Paint()..color = Colors.amber;
        const handleRadius = 8.0;
        canvas.drawCircle(screenRect.topLeft, handleRadius, handlePaint);
        canvas.drawCircle(screenRect.topRight, handleRadius, handlePaint);
        canvas.drawCircle(screenRect.bottomLeft, handleRadius, handlePaint);
        canvas.drawCircle(screenRect.bottomRight, handleRadius, handlePaint);
      }
    }

    // Draw the current box being created
    if (currentRect != null) {
      canvas.drawRect(currentRect!, paint);
    }

    // Restore canvas state if we applied transformation
    if (transformMatrix != null) {
      canvas.restore();
    }
  }

  void _drawText(Canvas canvas, Rect rect, String text) {
    final displayText = text.isEmpty ? 'Double-click to add text' : text;
    
    final textSpan = TextSpan(
      text: displayText,
      style: TextStyle(
        color: Colors.white, 
        fontSize: 14, 
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 2,
            color: Colors.black.withValues(alpha: 0.8),
          ),
        ],
      ),
    );
    
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout(
      minWidth: 0,
      maxWidth: rect.width - 4, // Leave some padding
    );
    
    final offset = Offset(
      rect.left + (rect.width - textPainter.width) / 2,
      rect.top + (rect.height - textPainter.height) / 2,
    );
    
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}