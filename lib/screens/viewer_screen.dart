import 'dart:io';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:qrganize/services/settings_service.dart';

import '../models/translation.dart';
import '../widgets/rectangle_painter.dart';

class ViewerScreen extends StatefulWidget {
  final List<File> imageFiles;
  final int initialIndex;

  const ViewerScreen({
    super.key, 
    required this.imageFiles,
    this.initialIndex = 0,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> with TickerProviderStateMixin {
  late int _currentImageIndex;
  late File _currentImageFile;
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
  String? _deeplTranslation;
  bool _showTranslationPanel = false;
  
  // UI Enhancement properties
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _showControls = true;
  bool _showCarouselSlider = false;
  bool _isFullscreen = false;
  bool _showOverlays = true;
  
  // Context menu related
  Offset? _contextMenuPosition;
  int? _contextMenuBoxIndex;
  OverlayEntry? _contextMenuEntry;
  
  // Tooltip related
  Offset? _tooltipPosition;
  String? _tooltipText;
  OverlayEntry? _tooltipEntry;

  // Focus node for keyboard navigation
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentImageIndex = widget.initialIndex;
    _currentImageFile = widget.imageFiles[_currentImageIndex];
    
    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
    
    _fadeController.forward();
    _slideController.forward();
    
    _loadImageSize();
    _loadTranslations();
  }


  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _focusNode.dispose();
    _removeContextMenu();
    _removeTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Stack(
          children: [
            // Main image viewer
            _buildImageViewer(),
            
            // Top controls bar
            _buildTopBar(),
            
            // Bottom carousel (appears on mouse hover)
            _buildBottomCarousel(),
            
            // Side navigation arrows (hidden in fullscreen)
            if (widget.imageFiles.length > 1 && !_isFullscreen) ...[
              _buildNavigationArrow(isLeft: true),
              _buildNavigationArrow(isLeft: false),
            ],
            
            // Mode toggle FAB
            _buildModeToggleFAB(),
            
            // Fullscreen overlay toggle button
            if (_isFullscreen) _buildOverlayToggleButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageViewer() {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: _imageSize == null
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    _calculateImageBounds(constraints);
                    
                    return Stack(
                      children: [
                        // Image centered in the screen
                        Center(
                          child: Hero(
                            tag: _currentImageFile.path,
                            child: Image.file(
                              _currentImageFile,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        // Main image interaction layer
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
                                    translations: _showOverlays ? _translations : [],
                                    currentRect: _currentRect,
                                    selectedBoxIndex: _isEditMode ? _selectedBoxIndex : null,
                                    hoveredBoxIndex: _hoveredBoxIndex,
                                    imageSize: _imageSize!,
                                    displayedImageSize: _displayedImageSize,
                                    imageOffset: _imageOffset,
                                    showText: _isEditMode,
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
        );
      },
    );
  }

  Widget _buildTopBar() {
    if (_isFullscreen) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Back button with enhanced styling
                      _buildTopBarButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back to Gallery',
                      ),
                      const SizedBox(width: 8),
                      
                      // File name and counter with better styling
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                path.basename(_currentImageFile.path),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.imageFiles.length > 1)
                                Text(
                                  '${_currentImageIndex + 1} of ${widget.imageFiles.length}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
                      // Action buttons with enhanced styling
                      if (_isEditMode) ...[
                        _buildTopBarButton(
                          icon: Icons.save,
                          onPressed: _saveTranslations,
                          tooltip: 'Save translations',
                          color: Colors.green,
                        ),
                        _buildTopBarButton(
                          icon: Icons.delete,
                          onPressed: _deleteSelectedBox,
                          tooltip: 'Delete selected box',
                          color: Colors.red,
                        ),
                      ],
                      
                      _buildTopBarButton(
                        icon: Icons.open_in_new,
                        onPressed: _open_with_photos,
                        tooltip: 'Open with Photos',
                      ),
                      
                      // Fullscreen toggle
                      _buildTopBarButton(
                        icon: _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        onPressed: _toggleFullscreen,
                        tooltip: _isFullscreen ? 'Exit fullscreen' : 'Enter fullscreen',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? Colors.white),
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 20,
      ),
    );
  }

  Widget _buildBottomCarousel() {
    if (widget.imageFiles.length <= 1 || _isEditMode || _isFullscreen) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: MouseRegion(
        onEnter: (_) => _showCarousel(),
        onExit: (_) => _hideCarousel(),
        child: AnimatedOpacity(
          opacity: _showCarouselSlider ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.9),
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
            child: SafeArea(
              child: _buildImageCarousel(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    return Row(
      children: [
        // Left scroll button
        if (_currentImageIndex > 0)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _previousImage();
            },
            child: Container(
              width: 50,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        
        // Image carousel
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: widget.imageFiles.length,
            itemBuilder: (context, index) {
              final isSelected = index == _currentImageIndex;
              return GestureDetector(
                onTap: () => _navigateToImage(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.6),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: isSelected 
                          ? Border.all(color: Colors.blue, width: 3) 
                          : Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          children: [
                            Image.file(
                              widget.imageFiles[index],
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                            ),
                            if (isSelected)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                              ),
                            if (isSelected)
                              const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                              ),
                            // Image number overlay
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Right scroll button
        if (_currentImageIndex < widget.imageFiles.length - 1)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _nextImage();
            },
            child: Container(
              width: 50,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
      ],
    );
  }


  Widget _buildNavigationArrow({required bool isLeft}) {
    final canNavigate = isLeft 
        ? _currentImageIndex > 0
        : _currentImageIndex < widget.imageFiles.length - 1;
        
    if (!canNavigate) return const SizedBox.shrink();
    
    return Positioned(
      left: isLeft ? 20 : null,
      right: isLeft ? null : 20,
      top: 0,
      bottom: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            isLeft ? _previousImage() : _nextImage();
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              isLeft ? Icons.chevron_left : Icons.chevron_right,
              color: Colors.white,
              size: 40,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggleFAB() {
    if (_isFullscreen) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      right: 32,
      bottom: 32,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: (_isEditMode ? Colors.orange : Colors.blue).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _toggleMode,
          backgroundColor: _isEditMode ? Colors.orange : Colors.blue,
          tooltip: _isEditMode ? 'Switch to View Mode' : 'Switch to Edit Mode',
          elevation: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _isEditMode ? Icons.visibility : Icons.edit,
              color: Colors.white,
              key: ValueKey(_isEditMode),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          _previousImage();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          _nextImage();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.escape:
          if (_isFullscreen) {
            _toggleFullscreen();
          } else {
            Navigator.of(context).pop();
          }
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyF:
          _toggleFullscreen();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyO:
          if (_isFullscreen) {
            _toggleOverlays();
          }
          return KeyEventResult.handled;
        case LogicalKeyboardKey.space:
          _toggleMode();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.delete:
          if (_isEditMode) {
            _deleteSelectedBox();
          }
          return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _showCarousel() {
    if (!_isEditMode) {
      setState(() {
        _showCarouselSlider = true;
      });
    }
  }

  void _hideCarousel() {
    setState(() {
      _showCarouselSlider = false;
    });
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      _showFullscreenHint();
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _showFullscreenHint() {
    if (widget.imageFiles.length <= 1) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.fullscreen, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Fullscreen Mode: Use ← → arrow keys to navigate • Press O to toggle overlays • Press ESC to exit',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black.withOpacity(0.8),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _toggleOverlays() {
    setState(() {
      _showOverlays = !_showOverlays;
    });
  }

  Widget _buildOverlayToggleButton() {
    return Positioned(
      top: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            _showOverlays ? Icons.visibility : Icons.visibility_off,
            color: Colors.white,
            size: 24,
          ),
          onPressed: _toggleOverlays,
          tooltip: _showOverlays ? 'Hide translation overlays' : 'Show translation overlays',
        ),
      ),
    );
  }

  void _navigateToImage(int index) {
    if (index == _currentImageIndex || index < 0 || index >= widget.imageFiles.length) {
      return;
    }
    
    // Add haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() {
      _currentImageIndex = index;
      _currentImageFile = widget.imageFiles[index];
      _translations.clear();
      _selectedBoxIndex = null;
      _currentRect = null;
      _imageSize = null;
    });
    
    _fadeController.reset();
    _fadeController.forward();
    
    _loadImageSize();
    _loadTranslations();
  }

  void _previousImage() {
    if (_currentImageIndex > 0) {
      _navigateToImage(_currentImageIndex - 1);
    }
  }

  void _nextImage() {
    if (_currentImageIndex < widget.imageFiles.length - 1) {
      _navigateToImage(_currentImageIndex + 1);
    }
  }


  // ... [Rest of the original methods remain the same] ...

  void _calculateImageBounds(BoxConstraints constraints) {
    if (_imageSize == null) return;

    final double imageAspectRatio = _imageSize!.width / _imageSize!.height;
    final double screenAspectRatio = constraints.maxWidth / constraints.maxHeight;

    double displayWidth, displayHeight;
    
    if (imageAspectRatio > screenAspectRatio) {
      displayWidth = constraints.maxWidth;
      displayHeight = displayWidth / imageAspectRatio;
    } else {
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
    
    final screenSize = MediaQuery.of(context).size;
    double left = position.dx;
    double top = position.dy - 40;
    
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

  void _open_with_photos() {
    if (Platform.isWindows) {
      final imagePath = _currentImageFile.path;
      Process.start('explorer.exe', [imagePath]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Open with Photos is only supported on Windows.'),
        ),
      );
    }
  }

  void _toggleMode() {
    // Add haptic feedback
    HapticFeedback.mediumImpact();
    
    setState(() {
      _isEditMode = !_isEditMode;
      _selectedBoxIndex = null;
      _currentRect = null;
      _dragStart = null;
      _isResizing = false;
      _isDragging = false;
      _showCarouselSlider = false; // Hide carousel in edit mode
    });
    _removeContextMenu();
    _removeTooltip();
    
    // Show mode change feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isEditMode ? Icons.edit : Icons.visibility,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              _isEditMode ? 'Edit Mode: Create and edit translation boxes' : 'View Mode: Navigate and view translations',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        backgroundColor: _isEditMode ? Colors.orange.withOpacity(0.9) : Colors.blue.withOpacity(0.9),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // [Include all remaining original methods: _onTapDown, _onViewTapDown, _onPanStart, 
  // _onPanUpdate, _onPanEnd, _onDoubleTapDown, _onHover, _loadImageSize, 
  // _loadTranslations, _saveTranslations, _deleteSelectedBox, _getTappedBoxIndex, 
  // _editBoxText, _getAbsoluteRect, _getResizeHandle, _resizeSelectedBox, 
  // _dragSelectedBox, _updateCursor, etc.]

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
      _updateCursor(SystemMouseCursors.basic);
      return;
    }

    if (_currentRect != null &&
        _currentRect!.width > 10 &&
        _currentRect!.height > 10 &&
        _displayedImageSize != null &&
        _imageOffset != null) {
      
      final imageRect = Rect.fromLTRB(
        (_currentRect!.left - _imageOffset!.dx) / _displayedImageSize!.width,
        (_currentRect!.top - _imageOffset!.dy) / _displayedImageSize!.height,
        (_currentRect!.right - _imageOffset!.dx) / _displayedImageSize!.width,
        (_currentRect!.bottom - _imageOffset!.dy) / _displayedImageSize!.height,
      );

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
      
      if (!_isEditMode && hoveredIndex != null && _showOverlays) {
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
    final image = await decodeImageFromList(_currentImageFile.readAsBytesSync());
    setState(() {
      _imageSize = Size(image.width.toDouble(), image.height.toDouble());
    });
  }

  Future<void> _loadTranslations() async {
    final jsonPath = '${path.withoutExtension(_currentImageFile.path)}.json';
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
    final jsonPath = '${path.withoutExtension(_currentImageFile.path)}.json';
    final jsonFile = File(jsonPath);
    final jsonString = json.encode(_translations.map((t) => t.toJson()).toList());
    await jsonFile.writeAsString(jsonString);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Translations saved!'),
        backgroundColor: Colors.green,
      ),
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
    bool isLoading = false;
    String? deeplTranslation;
    bool showTranslationPanel = false;

    final newText = await showDialog<String>(
      context: context,
      builder: (context) {
        String currentText = controller.text;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Translation'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.grey[900],
              titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8 > 600
                    ? 600
                    : MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Original Text',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLines: null,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (text) {
                        setState(() {
                          currentText = text;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter translation text...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[600]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[600]!),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, 
                          vertical: 8,
                        ),
                        fillColor: Colors.grey[800],
                        filled: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => Navigator.pop(context, currentText),
                    ),
                    if (showTranslationPanel) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Translated Text (DeepL)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[600]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[800],
                        ),
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Text(
                                deeplTranslation ?? 'No translation available.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: deeplTranslation != null
                                      ? Colors.white
                                      : Colors.grey[400],
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() {
                            showTranslationPanel = true;
                            isLoading = true;
                          });
                          final apiKey = await SettingsService.getDeepLApiKey();
                          if (apiKey == null || apiKey.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please set a DeepL API Key in Settings.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setState(() => isLoading = false);
                            return;
                          }
                          try {
                            final response = await http.post(
                              Uri.parse('https://api-free.deepl.com/v2/translate'),
                              headers: {
                                'Authorization': 'DeepL-Auth-Key $apiKey',
                                'Content-Type': 'application/json',
                              },
                              body: json.encode({
                                'text': [currentText],
                                'target_lang': 'EN',
                              }),
                            );
                            setState(() {
                              isLoading = false;
                              if (response.statusCode == 200) {
                                final jsonResponse = json.decode(response.body);
                                deeplTranslation = jsonResponse['translations'][0]['text'];
                              } else {
                                deeplTranslation = 'Translation failed. Please try again.';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${response.statusCode}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            });
                          } catch (e) {
                            setState(() {
                              isLoading = false;
                              deeplTranslation = 'Translation failed. Check your connection.';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  child: const Text('Translate (DeepL)', style: TextStyle(color: Colors.blue)),
                ),
                TextButton(
                  onPressed: () async {
                    final TextEditingController apiKeyController =
                        TextEditingController(
                            text: await SettingsService.getDeepLApiKey() ?? '');
                    await showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          backgroundColor: Colors.grey[900],
                          title: const Text(
                            'DeepL API Settings',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: TextField(
                            controller: apiKeyController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter DeepL API Key',
                              hintStyle: TextStyle(color: Colors.grey[400]),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[600]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey[600]!),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.blue),
                              ),
                              fillColor: Colors.grey[800],
                              filled: true,
                            ),
                            obscureText: true,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                            ),
                            TextButton(
                              onPressed: () async {
                                if (apiKeyController.text.isNotEmpty) {
                                  await SettingsService.saveDeepLApiKey(
                                      apiKeyController.text);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('API Key saved successfully!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.pop(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please enter a valid API Key.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Save', style: TextStyle(color: Colors.blue)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: const Text('Settings', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, currentText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
                if (deeplTranslation != null && deeplTranslation!.isNotEmpty)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, deeplTranslation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save Translation'),
                  ),
              ],
            );
          },
        );
      },
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