import 'dart:io';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import '../models/translation.dart';
import '../widgets/rectangle_painter.dart';

class ViewerScreen extends StatefulWidget {
  final File imageFile;

  const ViewerScreen({super.key, required this.imageFile});

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final List<Translation> _translations = [];
  Rect? _currentRect;
  int? _selectedBoxIndex;
  int? _hoveredBoxIndex;
  Size? _imageSize;
  Size? _displayedImageSize;
  Offset? _imageOffset;
  Offset? _dragStart;
  bool _isResizing = false;
  bool _isDragging = false;
  bool _isEditMode = false;
  Alignment? _resizeHandle;
  MouseCursor _currentCursor = SystemMouseCursors.basic;
  
  // Context menu related
  Offset? _contextMenuPosition;
  int? _contextMenuBoxIndex;
  OverlayEntry? _contextMenuEntry;
  
  // Tooltip related
  Offset? _tooltipPosition;
  String? _tooltipText;
  OverlayEntry? _tooltipEntry;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
    _loadTranslations();
  }

  @override
  void dispose() {
    _removeContextMenu();
    _removeTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(path.basename(widget.imageFile.path)),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.find_in_page : Icons.edit),
            onPressed: _toggleMode,
            tooltip: _isEditMode ? 'Switch to View Mode' : 'Switch to Edit Mode',
          ),
          if (_isEditMode) ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveTranslations,
              tooltip: 'Save translations',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedBox,
              tooltip: 'Delete selected box',
            ),
          ],
        ],
      ),
      body: _imageSize == null
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                // Calculate the actual displayed image size and position
                _calculateImageBounds(constraints);
                
                return Stack(
                  children: [
                    // Image centered in the screen
                    Center(
                      child: Image.file(widget.imageFile),
                    ),
                    Positioned.fill(
                      child: MouseRegion(
                        cursor: _currentCursor,
                        onHover: _onHover,
                        onExit: (_) => _removeTooltip(),
                        child: Listener(
                          onPointerDown: (event) {
                            if (event.buttons == kSecondaryMouseButton) {
                              _onRightClick(event);
                            }
                          },
                          child: GestureDetector(
                            onTapDown: _isEditMode ? _onTapDown : _onViewTapDown,
                            onPanStart: _isEditMode ? _onPanStart : null,
                            onPanUpdate: _isEditMode ? _onPanUpdate : null,
                            onPanEnd: _isEditMode ? _onPanEnd : null,
                            onDoubleTapDown: _isEditMode ? _onDoubleTapDown : null,
                            child: CustomPaint(
                              painter: RectanglePainter(
                                translations: _translations,
                                currentRect: _currentRect,
                                selectedBoxIndex: _isEditMode ? _selectedBoxIndex : null,
                                hoveredBoxIndex: _hoveredBoxIndex,
                                imageSize: _imageSize!,
                                displayedImageSize: _displayedImageSize,
                                imageOffset: _imageOffset,
                                showText: _isEditMode, // Show text preview in edit mode
                                isEditMode: _isEditMode,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleMode,
        tooltip: _isEditMode ? 'View Mode' : 'Edit Mode',
        child: Icon(_isEditMode ? Icons.find_in_page : Icons.edit),
      ),
    );
  }

  void _calculateImageBounds(BoxConstraints constraints) {
    if (_imageSize == null) return;

    final double imageAspectRatio = _imageSize!.width / _imageSize!.height;
    final double screenAspectRatio = constraints.maxWidth / constraints.maxHeight;

    double displayWidth, displayHeight;
    
    if (imageAspectRatio > screenAspectRatio) {
      // Image is wider than screen ratio
      displayWidth = constraints.maxWidth;
      displayHeight = displayWidth / imageAspectRatio;
    } else {
      // Image is taller than screen ratio
      displayHeight = constraints.maxHeight;
      displayWidth = displayHeight * imageAspectRatio;
    }

    _displayedImageSize = Size(displayWidth, displayHeight);
    _imageOffset = Offset(
      (constraints.maxWidth - displayWidth) / 2,
      (constraints.maxHeight - displayHeight) / 2,
    );
  }

  bool _isPointInImage(Offset point) {
    if (_imageOffset == null || _displayedImageSize == null) return false;
    
    final imageRect = Rect.fromLTWH(
      _imageOffset!.dx,
      _imageOffset!.dy,
      _displayedImageSize!.width,
      _displayedImageSize!.height,
    );
    
    return imageRect.contains(point);
  }

  Offset _globalToImageCoordinates(Offset globalPosition) {
    if (_imageOffset == null || _displayedImageSize == null) {
      return Offset.zero;
    }
    
    return Offset(
      globalPosition.dx - _imageOffset!.dx,
      globalPosition.dy - _imageOffset!.dy,
    );
  }

  void _onRightClick(PointerDownEvent event) {
    if (!_isPointInImage(event.localPosition)) return;

    final imagePosition = _globalToImageCoordinates(event.localPosition);
    final tappedIndex = _getTappedBoxIndex(imagePosition);

    if (_isEditMode && tappedIndex != null) {
      _showContextMenu(event.position, tappedIndex);
    } else {
      _removeContextMenu();
    }
  }

  void _showContextMenu(Offset position, int boxIndex) {
    _removeContextMenu();
    
    _contextMenuPosition = position;
    _contextMenuBoxIndex = boxIndex;
    
    _contextMenuEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 150,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildContextMenuItem(
                  icon: Icons.edit,
                  text: 'Edit Text',
                  onTap: () => _contextMenuAction(() => _editBoxText(boxIndex)),
                ),
                _buildContextMenuItem(
                  icon: Icons.content_copy,
                  text: 'Copy Text',
                  onTap: () => _contextMenuAction(() => _copyBoxText(boxIndex)),
                ),
                const Divider(height: 1),
                _buildContextMenuItem(
                  icon: Icons.delete,
                  text: 'Delete Box',
                  onTap: () => _contextMenuAction(() => _deleteBox(boxIndex)),
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_contextMenuEntry!);
    
    // Auto-remove context menu after delay or on next interaction
    Future.delayed(const Duration(seconds: 5), _removeContextMenu);
  }

  Widget _buildContextMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isDestructive ? Colors.red : Colors.grey[100],
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDestructive ? Colors.red : Colors.grey[100],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _contextMenuAction(VoidCallback action) {
    _removeContextMenu();
    action();
  }

  void _removeContextMenu() {
    _contextMenuEntry?.remove();
    _contextMenuEntry = null;
    _contextMenuPosition = null;
    _contextMenuBoxIndex = null;
  }

  void _copyBoxText(int index) {
    final text = _translations[index].text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text copied to clipboard!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _deleteBox(int index) {
    setState(() {
      _translations.removeAt(index);
      if (_selectedBoxIndex == index) {
        _selectedBoxIndex = null;
      } else if (_selectedBoxIndex != null && _selectedBoxIndex! > index) {
        _selectedBoxIndex = _selectedBoxIndex! - 1;
      }
    });
  }

  void _showTooltip(Offset position, String text) {
    if (text.isEmpty || _isEditMode) return;
    
    _removeTooltip();
    
    _tooltipPosition = position;
    _tooltipText = text;
    
    // Adjust position to keep tooltip on screen
    final screenSize = MediaQuery.of(context).size;
    double left = position.dx;
    double top = position.dy - 40;
    
    // Estimate tooltip width (rough calculation)
    final tooltipWidth = (text.length * 8.0).clamp(100.0, 300.0);
    
    if (left + tooltipWidth > screenSize.width) {
      left = screenSize.width - tooltipWidth - 10;
    }
    if (top < 0) {
      top = position.dy + 20;
    }
    
    _tooltipEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_tooltipEntry!);
  }

  void _removeTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
    _tooltipPosition = null;
    _tooltipText = null;
  }

  void _toggleMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      _selectedBoxIndex = null;
      _currentRect = null;
      _dragStart = null;
      _isResizing = false;
      _isDragging = false;
    });
    _removeContextMenu();
    _removeTooltip();
  }

  void _onTapDown(TapDownDetails details) {
    if (!_isEditMode || !_isPointInImage(details.localPosition)) {
      _removeContextMenu();
      return;
    }
    
    final imagePosition = _globalToImageCoordinates(details.localPosition);
    final tappedIndex = _getTappedBoxIndex(imagePosition);
    setState(() {
      _selectedBoxIndex = tappedIndex;
    });
    _removeContextMenu();
  }

  void _onViewTapDown(TapDownDetails details) {
    _removeTooltip();
  }

  void _onPanStart(DragStartDetails details) {
    if (!_isEditMode || !_isPointInImage(details.localPosition)) return;

    _removeContextMenu();
    final imagePosition = _globalToImageCoordinates(details.localPosition);
    final tappedIndex = _getTappedBoxIndex(imagePosition);
    
    if (tappedIndex != null) {
      setState(() {
        _selectedBoxIndex = tappedIndex;
      });
      
      final selectedRect = _getAbsoluteRect(_translations[tappedIndex]);
      _resizeHandle = _getResizeHandle(imagePosition, selectedRect);
      
      if (_resizeHandle != null) {
        _isResizing = true;
        _dragStart = details.localPosition;
        return;
      } else {
        _isDragging = true;
        _dragStart = details.localPosition;
        return;
      }
    }

    // Start creating new box
    _isResizing = false;
    _isDragging = false;
    _dragStart = details.localPosition;
    _currentRect = Rect.fromPoints(_dragStart!, _dragStart!);
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isEditMode) return;

    if (_isResizing && _selectedBoxIndex != null) {
      _resizeSelectedBox(details.localPosition);
    } else if (_isDragging && _selectedBoxIndex != null) {
      _dragSelectedBox(details.localPosition);
    } else if (_dragStart != null) {
      setState(() {
        _currentRect = Rect.fromPoints(_dragStart!, details.localPosition);
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isEditMode) return;

    if (_isResizing || _isDragging) {
      _isResizing = false;
      _isDragging = false;
      _dragStart = null;
      // Reset cursor after drag operation
      _updateCursor(SystemMouseCursors.basic);
      return;
    }

    if (_currentRect != null &&
        _currentRect!.width > 10 &&
        _currentRect!.height > 10 &&
        _displayedImageSize != null &&
        _imageOffset != null) {
      
      // Convert screen coordinates to image coordinates
      final imageRect = Rect.fromLTRB(
        (_currentRect!.left - _imageOffset!.dx) / _displayedImageSize!.width,
        (_currentRect!.top - _imageOffset!.dy) / _displayedImageSize!.height,
        (_currentRect!.right - _imageOffset!.dx) / _displayedImageSize!.width,
        (_currentRect!.bottom - _imageOffset!.dy) / _displayedImageSize!.height,
      );

      // Only add if the box is within image bounds
      if (imageRect.left >= 0 && imageRect.top >= 0 && 
          imageRect.right <= 1 && imageRect.bottom <= 1) {
        final newTranslation = Translation(
          left: imageRect.left,
          top: imageRect.top,
          right: imageRect.right,
          bottom: imageRect.bottom,
          text: '',
        );
        setState(() {
          _translations.add(newTranslation);
          _selectedBoxIndex = _translations.length - 1;
        });
      }
    }
    setState(() {
      _currentRect = null;
      setState(() {
        _currentCursor = SystemMouseCursors.basic;
      });
      // Reset cursor after creating new box using state management
      _currentCursor = SystemMouseCursors.basic;
    });
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (!_isEditMode || !_isPointInImage(details.localPosition)) return;

    final imagePosition = _globalToImageCoordinates(details.localPosition);
    final tappedIndex = _getTappedBoxIndex(imagePosition);
    if (tappedIndex != null) {
      _editBoxText(tappedIndex);
    }
  }

  void _onHover(PointerEvent details) {
    if (!_isPointInImage(details.localPosition)) {
      if (_hoveredBoxIndex != null) {
        setState(() {
          _hoveredBoxIndex = null;
        });
      }
      _removeTooltip();
      return;
    }

    final imagePosition = _globalToImageCoordinates(details.localPosition);
    final hoveredIndex = _getTappedBoxIndex(imagePosition);
    
    if (hoveredIndex != _hoveredBoxIndex) {
      setState(() {
        _hoveredBoxIndex = hoveredIndex;
      });
      
      // Show tooltip in view mode only
      if (!_isEditMode && hoveredIndex != null) {
        final text = _translations[hoveredIndex].text;
        if (text.isNotEmpty) {
          _showTooltip(details.position, text);
        } else {
          _removeTooltip();
        }
      } else {
        _removeTooltip();
      }
    }
  }

  void _loadImageSize() async {
    final image = await decodeImageFromList(widget.imageFile.readAsBytesSync());
    setState(() {
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());
    });
  }

  Future<void> _loadTranslations() async {
    final jsonPath = '${path.withoutExtension(widget.imageFile.path)}.json';
    final jsonFile = File(jsonPath);
    if (await jsonFile.exists()) {
      final jsonString = await jsonFile.readAsString();
      final List<dynamic> jsonList = json.decode(jsonString);
      setState(() {
        _translations.clear();
        _translations.addAll(jsonList.map((json) => Translation.fromJson(json)));
      });
    }
  }

  Future<void> _saveTranslations() async {
    final jsonPath = '${path.withoutExtension(widget.imageFile.path)}.json';
    final jsonFile = File(jsonPath);
    final jsonString = json.encode(_translations.map((t) => t.toJson()).toList());
    await jsonFile.writeAsString(jsonString);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Translations saved!')),
    );
  }

  void _deleteSelectedBox() {
    if (_selectedBoxIndex != null && _isEditMode) {
      setState(() {
        _translations.removeAt(_selectedBoxIndex!);
        _selectedBoxIndex = null;
      });
    }
  }

  int? _getTappedBoxIndex(Offset tapPosition) {
    if (_displayedImageSize == null) return null;
    
    for (int i = _translations.length - 1; i >= 0; i--) {
      final rect = _getAbsoluteRect(_translations[i]);
      if (rect.contains(tapPosition)) {
        return i;
      }
    }
    return null;
  }

  void _editBoxText(int index) async {
    final TextEditingController controller =
        TextEditingController(text: _translations[index].text);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Translation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Enter translation text...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newText != null) {
      setState(() {
        _translations[index].text = newText;
      });
    }
  }

  Rect _getAbsoluteRect(Translation t) {
    if (_displayedImageSize == null) return Rect.zero;
    
    return Rect.fromLTRB(
      t.left * _displayedImageSize!.width,
      t.top * _displayedImageSize!.height,
      t.right * _displayedImageSize!.width,
      t.bottom * _displayedImageSize!.height,
    );
  }

  Alignment? _getResizeHandle(Offset position, Rect rect) {
    const handleRadius = 12.0;
    if ((position - rect.topLeft).distance < handleRadius) return Alignment.topLeft;
    if ((position - rect.topRight).distance < handleRadius) return Alignment.topRight;
    if ((position - rect.bottomLeft).distance < handleRadius) return Alignment.bottomLeft;
    if ((position - rect.bottomRight).distance < handleRadius) return Alignment.bottomRight;
    return null;
  }

  void _resizeSelectedBox(Offset newPosition) {
    if (_selectedBoxIndex == null || _resizeHandle == null || 
        _displayedImageSize == null || _imageOffset == null) return;

    final translation = _translations[_selectedBoxIndex!];
    
    // Convert screen coordinates to image relative coordinates
    final oldImagePos = Offset(
      (_dragStart!.dx - _imageOffset!.dx) / _displayedImageSize!.width,
      (_dragStart!.dy - _imageOffset!.dy) / _displayedImageSize!.height,
    );
    
    final newImagePos = Offset(
      (newPosition.dx - _imageOffset!.dx) / _displayedImageSize!.width,
      (newPosition.dy - _imageOffset!.dy) / _displayedImageSize!.height,
    );
    
    final dx = newImagePos.dx - oldImagePos.dx;
    final dy = newImagePos.dy - oldImagePos.dy;
    
    double left = translation.left;
    double top = translation.top;
    double right = translation.right;
    double bottom = translation.bottom;

    if (_resizeHandle == Alignment.topLeft) {
      left += dx;
      top += dy;
    } else if (_resizeHandle == Alignment.topRight) {
      right += dx;
      top += dy;
    } else if (_resizeHandle == Alignment.bottomLeft) {
      left += dx;
      bottom += dy;
    } else if (_resizeHandle == Alignment.bottomRight) {
      right += dx;
      bottom += dy;
    }

    if (right - left > 0.01 && bottom - top > 0.01) {
      setState(() {
        _translations[_selectedBoxIndex!] = Translation(
          left: left.clamp(0.0, 1.0),
          top: top.clamp(0.0, 1.0),
          right: right.clamp(0.0, 1.0),
          bottom: bottom.clamp(0.0, 1.0),
          text: translation.text,
        );
      });
      _dragStart = newPosition;
    }
  }

  void _dragSelectedBox(Offset newPosition) {
    if (_selectedBoxIndex == null || _displayedImageSize == null || 
        _imageOffset == null) return;

    final translation = _translations[_selectedBoxIndex!];
    
    // Convert screen coordinates to image relative coordinates
    final dx = (newPosition.dx - _dragStart!.dx) / _displayedImageSize!.width;
    final dy = (newPosition.dy - _dragStart!.dy) / _displayedImageSize!.height;

    final width = translation.right - translation.left;
    final height = translation.bottom - translation.top;

    double newLeft = (translation.left + dx).clamp(0.0, 1.0 - width);
    double newTop = (translation.top + dy).clamp(0.0, 1.0 - height);
    double newRight = newLeft + width;
    double newBottom = newTop + height;

    setState(() {
      _translations[_selectedBoxIndex!] = Translation(
        left: newLeft,
        top: newTop,
        right: newRight,
        bottom: newBottom,
        text: translation.text,
      );
    });
    _dragStart = newPosition;
  }

  void _updateCursor(MouseCursor cursor) {
    setState(() {
      _currentCursor = cursor;
    });
  }
}