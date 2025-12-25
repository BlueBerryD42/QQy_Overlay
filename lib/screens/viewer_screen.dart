import 'dart:io';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/settings_service.dart';

import '../models/translation.dart';
import '../models/db/page_model.dart';
import '../models/db/overlay_box_model.dart';
import '../services/database_service.dart';
import '../repositories/page_repository.dart';
import '../repositories/overlay_box_repository.dart';
import '../widgets/rectangle_painter.dart';
import '../services/ocr_service.dart';

class ViewerScreen extends StatefulWidget {
  final List<File> imageFiles;
  final int initialIndex;
  final List<PageModel>? pages; // Optional: if provided, use for database operations

  const ViewerScreen({
    super.key, 
    required this.imageFiles,
    this.initialIndex = 0,
    this.pages,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> with TickerProviderStateMixin {
  // Static variable to track if WebView has been loaded globally (persists across screen instances)
  static bool _globalWebViewLoaded = false;
  static InAppWebViewController? _globalWebViewController;
  
  late int _currentImageIndex;
  late File _currentImageFile;
  final List<Translation> _translations = [];
  Rect? _currentRect;
  int? _selectedBoxIndex;
  int? _hoveredBoxIndex;
  Size? _imageSize;
  Size? _displayedImageSize;
  Offset? _imageOffset;
  Offset? _actualImageOffset; // NEW: Track ACTUAL image offset from Image widget
  Size? _actualImageSize;     // NEW: Track ACTUAL displayed size from Image widget
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
  
  // Draggable dock position (for controls dock - separate from Grok)
  Offset _dockPosition = const Offset(16, 16); // Controls dock position
  bool _isDraggingDock = false;
  
  // Combined Grok container position (menu + WebView)
  Offset _grokContainerPosition = const Offset(16, 16); // Can be dragged anywhere
  bool _isDraggingGrok = false;
  bool _showWebView = false;
  Size _webViewSize = const Size(400, 600); // Default mobile-like size
  bool _isResizingWebView = false;
  Offset? _resizeStartPosition;
  Size? _resizeStartSize;
  InAppWebViewController? _grokWebViewController;
  bool _isReloadingWebView = false; // Flag to prevent infinite reload loop
  bool _isHoveringTopBar = false; // Track hover state for top bar
  bool _hasWebViewLoaded = false; // Track if WebView has been loaded at least once (instance-level)
  
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

  // Database services
  final DatabaseService _dbService = DatabaseService();
  PageRepository? _pageRepository;
  OverlayBoxRepository? _overlayBoxRepository;
  int? _currentPageId;
  
  // OCR service
  OcrService? _ocrService;
  bool _isProcessingOcr = false;
  
  // Zoom/Pan controller
  final TransformationController _transformationController = TransformationController();

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
    
    _initializeDatabase().then((_) {
      _loadImageSize();
      _loadTranslations();
    });
    
    // Initialize OCR service
    _ocrService = OcrService();
  }

  Future<void> _initializeDatabase() async {
    await _dbService.initializeDatabase();
    _pageRepository = PageRepository(_dbService);
    _overlayBoxRepository = OverlayBoxRepository(_dbService);
    
    // Find current page ID if pages are provided
    if (widget.pages != null && widget.pages!.isNotEmpty) {
      // Match by index first (most reliable when pages are in order)
      if (_currentImageIndex < widget.pages!.length) {
        _currentPageId = widget.pages![_currentImageIndex].pageId;
        debugPrint('ViewerScreen: Set pageId to ${_currentPageId} from pages[${_currentImageIndex}]');
      } else {
        // Fallback: try to match by file path
        final currentPage = widget.pages!.firstWhere(
          (p) => p.storagePath == _currentImageFile.path,
          orElse: () => widget.pages![0],
        );
        _currentPageId = currentPage.pageId;
        debugPrint('ViewerScreen: Set pageId to ${_currentPageId} from path match (fallback)');
      }
    } else {
      debugPrint('ViewerScreen: No pages provided, trying to find by path');
      // Try to find page by file path
      _currentPageId = await _findPageIdByPath(_currentImageFile.path);
      debugPrint('ViewerScreen: Found pageId by path: $_currentPageId');
    }
  }

  Future<int?> _findPageIdByPath(String filePath) async {
    if (_pageRepository == null) return null;
    
    try {
      // This is a simplified lookup - in production you might want to cache this
      // For now, we'll search by matching the path
      // Note: This is not efficient for large databases, but works for the migration
      return null; // Will fall back to JSON if not found
    } catch (e) {
      return null;
    }
  }


  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _focusNode.dispose();
    _transformationController.dispose();
    _removeContextMenu();
    _removeTooltip();
    _ocrService?.dispose();
    _dbService.dispose();
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
            
            // Combined controls dock and Grok WebView (unified UI)
            _buildGrokWebView(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
            
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
                    
                    return InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.5,
                      maxScale: 5.0,
                      boundaryMargin: const EdgeInsets.all(100),
                      panEnabled: !_isEditMode, // Disable pan in edit mode to allow box creation
                      scaleEnabled: !_isEditMode, // Disable zoom in edit mode
                      constrained: false,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Stack(
                          children: [
                            // Image centered in the screen
                            Center(
                              child: Hero(
                                tag: _currentImageFile.path,
                                child: Image.file(
                                  _currentImageFile,
                                  fit: BoxFit.contain,
                                  key: const ValueKey('main_image'),
                                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                    // Calculate ACTUAL image position after layout
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      final renderBox = context.findRenderObject() as RenderBox?;
                                      if (renderBox != null && renderBox.hasSize) {
                                        final imagePosition = renderBox.localToGlobal(Offset.zero);
                                        final imageSize = renderBox.size;
                                        
                                        // Update ACTUAL offset and size
                                        setState(() {
                                          _actualImageOffset = imagePosition;
                                          _actualImageSize = imageSize;
                                        });
                                      }
                                    });
                                    return child;
                                  },
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
                                        displayedImageSize: _actualImageSize ?? _displayedImageSize, // Use ACTUAL if available
                                        imageOffset: _actualImageOffset ?? _imageOffset,            // Use ACTUAL if available
                                        showText: _isEditMode,
                                        isEditMode: _isEditMode,
                                        transformMatrix: _transformationController.value, // Pass transform for zoom/pan
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildDraggableDock() {
    if (_isFullscreen) {
      return const SizedBox.shrink();
    }
    
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width;
    final maxHeight = screenSize.height;
    
    // Don't render WebView here - it's rendered separately in the main Stack
    
    // Original controls dock
    return Positioned(
      left: _dockPosition.dx.clamp(0.0, maxWidth - 400),
      top: _dockPosition.dy.clamp(0.0, maxHeight - 80),
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: GestureDetector(
          onPanStart: (details) {
            setState(() {
              _isDraggingDock = true;
            });
          },
          onPanUpdate: (details) {
            setState(() {
              final newX = (_dockPosition.dx + details.delta.dx).clamp(0.0, maxWidth - 400);
              final newY = (_dockPosition.dy + details.delta.dy).clamp(0.0, maxHeight - 80);
              _dockPosition = Offset(newX, newY);
            });
          },
          onPanEnd: (details) {
            setState(() {
              _isDraggingDock = false;
            });
          },
          child: MouseRegion(
            cursor: _isDraggingDock ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag handle
                      MouseRegion(
                        cursor: SystemMouseCursors.move,
                        child: Container(
                          width: 4,
                          height: 40,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      
                      // Back button
                      _buildDockButton(
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Back to Gallery',
                      ),
                      const SizedBox(width: 6),
                      
                      // File name and counter
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                path.basename(_currentImageFile.path),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              if (widget.imageFiles.length > 1)
                                Text(
                                  '${_currentImageIndex + 1} of ${widget.imageFiles.length}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      
                      // Action buttons
                      if (_isEditMode) ...[
                        _buildDockButton(
                          icon: Icons.save,
                          onPressed: _saveTranslations,
                          tooltip: 'Save translations',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 6),
                        _buildDockButton(
                          icon: Icons.delete,
                          onPressed: _deleteSelectedBox,
                          tooltip: 'Delete selected box',
                          color: Colors.red,
                        ),
                        const SizedBox(width: 6),
                      ],
                      
                      _buildDockButton(
                        icon: Icons.open_in_new,
                        onPressed: _open_with_photos,
                        tooltip: 'Open with Photos',
                      ),
                      const SizedBox(width: 6),
                      
                      // Grok AI WebView toggle
                      _buildDockButton(
                        icon: Icons.chat_bubble_outline,
                        onPressed: () {
                          setState(() {
                            _showWebView = !_showWebView;
                            // No need to reload - WebView is kept alive with maintainState: true
                          });
                        },
                        tooltip: _showWebView ? 'Hide Grok AI' : 'Show Grok AI',
                        color: _showWebView ? Colors.blue : null,
                      ),
                      const SizedBox(width: 6),
                      
                      // Fullscreen toggle
                      _buildDockButton(
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
        ),
      ),
    );
  }
  
  Widget _buildGrokWebView(double maxWidth, double maxHeight) {
    final topBarHeight = 70.0; // Height of top bar menu (increased to fit all controls and prevent overflow)
    final containerHeight = _showWebView ? topBarHeight + _webViewSize.height : topBarHeight;
    final maxTop = maxHeight - containerHeight;
    final adjustedTop = _grokContainerPosition.dy.clamp(0.0, maxTop);
    final adjustedLeft = _grokContainerPosition.dx.clamp(0.0, maxWidth - _webViewSize.width);
    
    return Positioned(
      left: adjustedLeft,
      top: adjustedTop,
      child: Visibility(
        visible: true, // Container always visible, WebView inside is controlled by _showWebView
        maintainState: true,
        maintainSize: false,
        maintainAnimation: true,
        child: GestureDetector(
          onPanStart: (details) {
            if (!_isResizingWebView) {
              setState(() {
                _isDraggingGrok = true;
              });
            }
          },
          onPanUpdate: (details) {
            if (_isResizingWebView) {
              // Resize container (affects WebView size)
              final topBarHeight = 70.0;
              setState(() {
                final newWidth = (_resizeStartSize!.width + details.delta.dx).clamp(300.0, maxWidth - _grokContainerPosition.dx);
                final containerHeight = topBarHeight + (_showWebView ? _webViewSize.height : 0);
                final maxAllowedHeight = maxHeight - _grokContainerPosition.dy - topBarHeight;
                final newHeight = (_resizeStartSize!.height + details.delta.dy).clamp(400.0, maxAllowedHeight);
                _webViewSize = Size(newWidth, newHeight);
              });
            } else {
              // Drag entire container (menu + WebView)
              final topBarHeight = 70.0;
              final containerHeight = topBarHeight + (_showWebView ? _webViewSize.height : 0);
              final maxTop = maxHeight - containerHeight;
              setState(() {
                final newX = (_grokContainerPosition.dx + details.delta.dx).clamp(0.0, maxWidth - _webViewSize.width);
                final newY = (_grokContainerPosition.dy + details.delta.dy).clamp(0.0, maxTop);
                _grokContainerPosition = Offset(newX, newY);
              });
            }
          },
          onPanEnd: (details) {
            setState(() {
              _isDraggingGrok = false;
              _isResizingWebView = false;
            });
          },
          child: Container(
            width: _webViewSize.width,
            height: containerHeight, // Explicit height to prevent layout issues
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
              // Top bar menu - combined controls dock and Grok toggle
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 70, // Increased height to fit all controls and prevent overflow
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          MouseRegion(
                            cursor: SystemMouseCursors.move,
                            child: Container(
                              width: 4,
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          
                          // Back button
                          _buildDockButton(
                            icon: Icons.arrow_back,
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Back to Gallery',
                          ),
                          const SizedBox(width: 6),
                          
                          // File name and counter
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    path.basename(_currentImageFile.path),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  if (widget.imageFiles.length > 1)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '${_currentImageIndex + 1} of ${widget.imageFiles.length}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 11,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          
                          // Action buttons
                          if (_isEditMode) ...[
                            _buildDockButton(
                              icon: Icons.save,
                              onPressed: _saveTranslations,
                              tooltip: 'Save translations',
                              color: Colors.green,
                            ),
                            const SizedBox(width: 6),
                            _buildDockButton(
                              icon: Icons.delete,
                              onPressed: _deleteSelectedBox,
                              tooltip: 'Delete selected box',
                              color: Colors.red,
                            ),
                            const SizedBox(width: 6),
                          ],
                          
                          _buildDockButton(
                            icon: Icons.open_in_new,
                            onPressed: _open_with_photos,
                            tooltip: 'Open with Photos',
                          ),
                          const SizedBox(width: 6),
                          
                          // Grok AI WebView toggle
                          _buildDockButton(
                            icon: Icons.chat_bubble_outline,
                            onPressed: () {
                              setState(() {
                                _showWebView = !_showWebView;
                                // No need to reload - WebView is kept alive with maintainState: true
                              });
                            },
                            tooltip: _showWebView ? 'Hide Grok AI' : 'Show Grok AI',
                            color: _showWebView ? Colors.blue : null,
                          ),
                          const SizedBox(width: 6),
                          
                          // OCR button (only show in edit mode when box is selected)
                          if (_isEditMode && _selectedBoxIndex != null)
                            _buildDockButton(
                              icon: Icons.text_fields,
                              onPressed: _isProcessingOcr 
                                ? () {} // Empty function when processing
                                : () => _performOcrForBox(_selectedBoxIndex!),
                              tooltip: _isProcessingOcr ? 'Processing OCR...' : 'OCR Selected Box',
                              color: _isProcessingOcr ? Colors.grey : Colors.purple,
                            ),
                          if (_isEditMode && _selectedBoxIndex != null) const SizedBox(width: 6),
                          
                          // Reload Grok WebView button (only show when WebView is visible)
                          if (_showWebView)
                            _buildDockButton(
                              icon: Icons.refresh,
                              onPressed: () async {
                                if (_grokWebViewController != null) {
                                  debugPrint('Manually reloading Grok WebView...');
                                  await _grokWebViewController!.reload();
                                } else if (_globalWebViewController != null) {
                                  debugPrint('Manually reloading Grok WebView using global controller...');
                                  await _globalWebViewController!.reload();
                                }
                              },
                              tooltip: 'Reload Grok AI',
                              color: Colors.orange,
                            ),
                          if (_showWebView) const SizedBox(width: 6),
                          
                          _buildDockButton(
                            icon: Icons.fullscreen,
                            onPressed: () {
                              setState(() {
                                _showControls = !_showControls;
                              });
                            },
                            tooltip: 'Toggle fullscreen',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Grok WebView - shown when _showWebView is true
              Positioned(
                top: 70, // Below top bar
                left: 0,
                right: 0,
                child: Visibility(
                  visible: _showWebView,
                  maintainState: true,
                  maintainSize: true, // Keep size to prevent layout issues
                  maintainAnimation: true,
                  child: IgnorePointer(
                    ignoring: !_showWebView, // Ignore pointer events when hidden
                    child: SizedBox(
                      width: _webViewSize.width,
                      height: _webViewSize.height,
                      child: InAppWebView(
                      key: const ValueKey('grok_webview_persistent'), // Fixed key to prevent recreation
                      initialUrlRequest: URLRequest(
                        url: WebUri('https://grok.com/'),
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        domStorageEnabled: true,
                        transparentBackground: false,
                        thirdPartyCookiesEnabled: true,
                        cacheEnabled: true,
                        useShouldOverrideUrlLoading: true,
                        supportMultipleWindows: true,
                        javaScriptCanOpenWindowsAutomatically: true,
                        // Use desktop user agent for Windows
                        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                      ),
                      onWebViewCreated: (controller) {
                        // Store controller globally and locally
                        _grokWebViewController = controller;
                        _globalWebViewController = controller;
                        _isReloadingWebView = false;
                        
                        // Only load URL once globally (first time app opens)
                        if (!_globalWebViewLoaded) {
                          debugPrint('Grok WebView created for the first time globally - loading URL');
                          WidgetsBinding.instance.addPostFrameCallback((_) async {
                            if (mounted && _grokWebViewController != null && !_globalWebViewLoaded) {
                              await Future.delayed(const Duration(milliseconds: 300));
                              if (mounted && _grokWebViewController != null && !_globalWebViewLoaded) {
                                try {
                                  if (_grokWebViewController == null || !mounted) {
                                    debugPrint('WebView controller is null or widget unmounted, skipping load');
                                    return;
                                  }
                                  final currentUrl = await _grokWebViewController!.getUrl();
                                  if (currentUrl == null || currentUrl.toString().isEmpty || currentUrl.toString() == 'about:blank') {
                                    debugPrint('WebView is blank, loading URL for the first time globally...');
                                    if (_grokWebViewController != null && mounted) {
                                      await _grokWebViewController!.loadUrl(
                                        urlRequest: URLRequest(
                                          url: WebUri('https://grok.com/'),
                                        ),
                                      );
                                      _globalWebViewLoaded = true;
                                      _hasWebViewLoaded = true;
                                      debugPrint('WebView loaded globally - will not reload on future instances');
                                    }
                                  } else {
                                    debugPrint('WebView already has URL: $currentUrl, marking as loaded globally');
                                    _globalWebViewLoaded = true;
                                    _hasWebViewLoaded = true;
                                  }
                                } catch (e) {
                                  debugPrint('Error checking/loading URL: $e');
                                  _globalWebViewLoaded = true;
                                  _hasWebViewLoaded = true;
                                }
                              }
                            }
                          });
                        } else {
                          // WebView already loaded globally - reuse existing controller
                          debugPrint('WebView already loaded globally - reusing controller without reload');
                          _hasWebViewLoaded = true;
                        }
                      },
                      onLoadStart: (controller, url) {
                        debugPrint('Grok WebView load start: $url');
                      },
                      onLoadStop: (controller, url) async {
                        debugPrint('Grok WebView load stop: $url');
                        try {
                          // Wait a bit for page to fully render
                          await Future.delayed(const Duration(milliseconds: 500));
                          // Inject CSS to ensure mobile responsive view
                          await controller.evaluateJavascript(source: '''
                            (function() {
                              var meta = document.querySelector('meta[name="viewport"]');
                              if (!meta) {
                                meta = document.createElement('meta');
                                meta.name = 'viewport';
                                document.getElementsByTagName('head')[0].appendChild(meta);
                              }
                              meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                              
                              // Also try to set body width for better mobile view
                              var body = document.body;
                              if (body) {
                                body.style.width = '100%';
                                body.style.maxWidth = '100%';
                                body.style.overflowX = 'hidden';
                              }
                            })();
                          ''');
                        } catch (e) {
                          debugPrint('Error injecting viewport meta: $e');
                        }
                      },
                      onReceivedError: (controller, request, error) {
                        // Ignore expected connection errors during initialization (common on Windows)
                        if (error.type == WebResourceErrorType.CANCELLED || 
                            error.type == WebResourceErrorType.CONNECTION_ABORTED) {
                          // These are expected during WebView initialization on Windows and can be safely ignored
                          return;
                        }
                        // Only log actual errors that need attention
                        debugPrint('Grok WebView error: ${error.description} (type: ${error.type})');
                      },
                      onReceivedHttpError: (controller, request, response) {
                        final statusCode = response.statusCode;
                        debugPrint('Grok WebView HTTP error: $statusCode');
                      },
                      shouldOverrideUrlLoading: (controller, navigationAction) async {
                        // Allow all navigation
                        return NavigationActionPolicy.ALLOW;
                      },
                      onCreateWindow: (controller, createWindowAction) async {
                        debugPrint('Grok WebView create window: ${createWindowAction.request.url}');
                        await controller.loadUrl(urlRequest: createWindowAction.request);
                        return true;
                      },
                      onReceivedServerTrustAuthRequest: (controller, challenge) async {
                        return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                      },
                    ),
                    ),
                  ),
                ),
              ),
              // Resize handle (bottom-right corner) - only show when WebView is visible
              ...(_showWebView ? [
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        _isResizingWebView = true;
                        _resizeStartSize = _webViewSize;
                        _resizeStartPosition = details.localPosition;
                      });
                    },
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.7),
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(10),
                          ),
                        ),
                        child: const Icon(
                          Icons.drag_handle,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ] : []),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDockButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color ?? Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
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
          // Priority 1: If currently drawing an overlay box, cancel it
          if (_currentRect != null) {
            setState(() {
              _currentRect = null;
              _currentCursor = SystemMouseCursors.basic;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Overlay creation cancelled'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 1),
              ),
            );
            return KeyEventResult.handled;
          }
          // Priority 2: If OCR is processing, show warning but don't cancel (let it finish)
          if (_isProcessingOcr) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('OCR in progress, please wait...'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 1),
              ),
            );
            return KeyEventResult.handled;
          }
          // Priority 3: If in fullscreen, exit fullscreen
          if (_isFullscreen) {
            _toggleFullscreen();
          } else {
            // Priority 4: Exit to gallery
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
        case LogicalKeyboardKey.keyR:
          // Reset zoom/pan (press R)
          _resetZoom();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.digit0:
          // Reset zoom/pan (press 0)
          if (event.logicalKey == LogicalKeyboardKey.digit0) {
            _resetZoom();
            return KeyEventResult.handled;
          }
          break;
      }
    }
    return KeyEventResult.ignored;
  }
  
  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.zoom_out_map, color: Colors.white),
            SizedBox(width: 8),
            Text('Zoom reset to 100%'),
          ],
        ),
        backgroundColor: Colors.blue.withOpacity(0.9),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
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
    
    // Reset zoom/pan when changing images
    _transformationController.value = Matrix4.identity();
    
    setState(() {
      _currentImageIndex = index;
      _currentImageFile = widget.imageFiles[index];
      _translations.clear();
      _selectedBoxIndex = null;
      _currentRect = null;
      _imageSize = null;
    });

    // Update current page ID
    if (widget.pages != null && index < widget.pages!.length) {
      // Match by index first (most reliable)
      _currentPageId = widget.pages![index].pageId;
      debugPrint('ViewerScreen: Navigated to image $index, set pageId to $_currentPageId');
    } else if (widget.pages != null && widget.pages!.isNotEmpty) {
      // Fallback: try to match by file path
      final matchingPage = widget.pages!.firstWhere(
        (p) => p.storagePath == _currentImageFile.path,
        orElse: () => widget.pages![0],
      );
      _currentPageId = matchingPage.pageId;
      debugPrint('ViewerScreen: Navigated to image $index, set pageId to $_currentPageId (fallback)');
    } else {
      // Try to find page by file path (async)
      _currentPageId = null;
      debugPrint('ViewerScreen: No pages provided, trying to find pageId by path');
      _findPageIdByPath(_currentImageFile.path).then((pageId) {
        if (mounted) {
          debugPrint('ViewerScreen: Found pageId by path: $pageId');
          setState(() {
            _currentPageId = pageId;
          });
          _loadTranslations();
        }
      });
    }
    
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
    // Use ACTUAL offset/size for consistency
    final effectiveOffset = _actualImageOffset ?? _imageOffset;
    final effectiveSize = _actualImageSize ?? _displayedImageSize;
    
    if (effectiveOffset == null || effectiveSize == null) return false;
    
    final imageRect = Rect.fromLTWH(
      effectiveOffset.dx,
      effectiveOffset.dy,
      effectiveSize.width,
      effectiveSize.height,
    );
    
    return imageRect.contains(point);
  }

  Offset _globalToImageCoordinates(Offset globalPosition) {
    // Use ACTUAL offset for consistency
    final effectiveOffset = _actualImageOffset ?? _imageOffset;
    
    if (effectiveOffset == null) {
      return Offset.zero;
    }
    
    // Return position relative to image top-left (but still in screen pixels)
    return Offset(
      globalPosition.dx - effectiveOffset.dx,
      globalPosition.dy - effectiveOffset.dy,
    );
  }

  void _onRightClick(PointerDownEvent event) {
    if (!_isPointInImage(event.localPosition)) return;

    // Pass screen coordinates directly
    final tappedIndex = _getTappedBoxIndex(event.localPosition);

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
                  icon: Icons.text_fields,
                  text: 'OCR Text',
                  onTap: () => _contextMenuAction(() => _performOcrForBox(boxIndex)),
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
    
    // If switching TO Edit Mode, reset zoom to 1:1 for accurate overlay drawing
    if (!_isEditMode) {
      _transformationController.value = Matrix4.identity();
    }
    
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
              _isEditMode ? 'Edit Mode: Zoom locked at 100% for accurate overlay drawing' : 'View Mode: Zoom/pan enabled for navigation',
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
    
    // Pass screen coordinates directly
    final tappedIndex = _getTappedBoxIndex(details.localPosition);
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
    // Pass screen coordinates directly (not image-relative)
    final tappedIndex = _getTappedBoxIndex(details.localPosition);
    
    if (tappedIndex != null) {
      setState(() {
        _selectedBoxIndex = tappedIndex;
      });
      
      final selectedRect = _getAbsoluteRect(_translations[tappedIndex]);
      // Use screen coordinates for resize handle detection
      _resizeHandle = _getResizeHandle(details.localPosition, selectedRect);
      
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
        _imageSize != null) {
      
      // Use ACTUAL offset/size if available, otherwise use calculated values
      final effectiveOffset = _actualImageOffset ?? _imageOffset;
      final effectiveSize = _actualImageSize ?? _displayedImageSize;
      
      if (effectiveOffset == null || effectiveSize == null) {
        debugPrint('ViewerScreen: ERROR - No effective offset/size available!');
        setState(() {
          _currentRect = null;
          _currentCursor = SystemMouseCursors.basic;
        });
        return;
      }
      
      // Debug: Print current state
      debugPrint('ViewerScreen: ===== OVERLAY CREATION DEBUG =====');
      debugPrint('ViewerScreen: _currentRect (screen): ${_currentRect!.left.toStringAsFixed(1)}, ${_currentRect!.top.toStringAsFixed(1)}, ${_currentRect!.right.toStringAsFixed(1)}, ${_currentRect!.bottom.toStringAsFixed(1)}');
      debugPrint('ViewerScreen: effectiveOffset: ${effectiveOffset.dx.toStringAsFixed(1)}, ${effectiveOffset.dy.toStringAsFixed(1)}');
      debugPrint('ViewerScreen: effectiveSize: ${effectiveSize.width.toStringAsFixed(1)}x${effectiveSize.height.toStringAsFixed(1)}');
      debugPrint('ViewerScreen: imageSize: ${_imageSize!.width.toInt()}x${_imageSize!.height.toInt()}');
      
      // IMPORTANT: _currentRect is in absolute screen coordinates
      // We need to convert to coordinates RELATIVE to the displayed image
      
      // Step 1: Convert screen coords to displayed image coords (subtract ACTUAL offset)
      final displayedLeft = _currentRect!.left - effectiveOffset.dx;
      final displayedTop = _currentRect!.top - effectiveOffset.dy;
      final displayedRight = _currentRect!.right - effectiveOffset.dx;
      final displayedBottom = _currentRect!.bottom - effectiveOffset.dy;
      
      debugPrint('ViewerScreen: Displayed coords: ${displayedLeft.toStringAsFixed(1)}, ${displayedTop.toStringAsFixed(1)}, ${displayedRight.toStringAsFixed(1)}, ${displayedBottom.toStringAsFixed(1)}');
      
      // Step 2: Convert to relative coordinates (0-1) based on ACTUAL displayed size
      final relativeLeft = displayedLeft / effectiveSize.width;
      final relativeTop = displayedTop / effectiveSize.height;
      final relativeRight = displayedRight / effectiveSize.width;
      final relativeBottom = displayedBottom / effectiveSize.height;
      
      debugPrint('ViewerScreen: Relative coords: ${relativeLeft.toStringAsFixed(4)}, ${relativeTop.toStringAsFixed(4)}, ${relativeRight.toStringAsFixed(4)}, ${relativeBottom.toStringAsFixed(4)}');
      
      final imageRect = Rect.fromLTRB(
        relativeLeft,
        relativeTop,
        relativeRight,
        relativeBottom,
      );
      
      // Calculate absolute pixels in actual image for verification
      final absoluteLeft = (relativeLeft * _imageSize!.width).floor();
      final absoluteTop = (relativeTop * _imageSize!.height).floor();
      final absoluteRight = (relativeRight * _imageSize!.width).ceil();
      final absoluteBottom = (relativeBottom * _imageSize!.height).ceil();
      
      debugPrint('ViewerScreen: Absolute pixels: $absoluteLeft, $absoluteTop, $absoluteRight, $absoluteBottom (${absoluteRight - absoluteLeft}x${absoluteBottom - absoluteTop})');
      debugPrint('ViewerScreen: =====================================');

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
      
      // Auto trigger OCR for new box ONLY if widget is still mounted
      // Use post frame callback to ensure state is updated first
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedBoxIndex != null) {
            _performOcrForBox(_selectedBoxIndex!);
          }
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

    // Pass screen coordinates directly
    final tappedIndex = _getTappedBoxIndex(details.localPosition);
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

    // Pass screen coordinates directly
    final hoveredIndex = _getTappedBoxIndex(details.localPosition);
    
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
    setState(() {
      _translations.clear();
    });

    // Try to load from database first
    if (_currentPageId != null && _overlayBoxRepository != null) {
      try {
        debugPrint('ViewerScreen: Loading translations for pageId: $_currentPageId');
        final overlayBoxes = await _overlayBoxRepository!.getOverlayBoxesByPageId(_currentPageId!);
        debugPrint('ViewerScreen: Loaded ${overlayBoxes.length} overlay boxes from database');
        
        final newTranslations = overlayBoxes.map((box) {
          // Convert OverlayBoxModel to Translation
          // OverlayBox uses x, y, width, height (normalized 0-1)
          // Translation uses left, top, right, bottom (normalized 0-1)
          return Translation(
            left: box.x,
            top: box.y,
            right: box.x + box.width,
            bottom: box.y + box.height,
            text: box.translatedText ?? box.originalText ?? '',
          );
        }).toList();
        
        debugPrint('ViewerScreen: Converted to ${newTranslations.length} translations');
        setState(() {
          _translations.clear();
          _translations.addAll(newTranslations);
        });
        return;
      } catch (e, stackTrace) {
        debugPrint('ViewerScreen: Error loading translations from database: $e');
        debugPrint('ViewerScreen: Stack trace: $stackTrace');
        // Fall back to JSON if database fails
      }
    } else {
      debugPrint('ViewerScreen: Cannot load from database - pageId: $_currentPageId, repository: ${_overlayBoxRepository != null}');
    }

    // Fall back to JSON file (for backward compatibility)
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
    debugPrint('ViewerScreen: Saving translations - pageId: $_currentPageId, repository: ${_overlayBoxRepository != null}, count: ${_translations.length}');
    
    if (_currentPageId == null || _overlayBoxRepository == null) {
      debugPrint('ViewerScreen: Cannot save to database, falling back to JSON');
      // Fall back to JSON if no page ID
      final jsonPath = '${path.withoutExtension(_currentImageFile.path)}.json';
      final jsonFile = File(jsonPath);
      final jsonString = json.encode(_translations.map((t) => t.toJson()).toList());
      await jsonFile.writeAsString(jsonString);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translations saved to JSON!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    try {
      debugPrint('ViewerScreen: Deleting existing overlay boxes for pageId: $_currentPageId');
      // Delete existing overlay boxes for this page
      await _overlayBoxRepository!.deleteOverlayBoxesByPageId(_currentPageId!);

      // Create new overlay boxes
      final now = DateTime.now();
      debugPrint('ViewerScreen: Creating ${_translations.length} new overlay boxes');
      for (int i = 0; i < _translations.length; i++) {
        final translation = _translations[i];
        final overlayBox = OverlayBoxModel(
          pageId: _currentPageId!,
          x: translation.left,
          y: translation.top,
          width: translation.right - translation.left,
          height: translation.bottom - translation.top,
          translatedText: translation.text,
          createdAt: now,
          updatedAt: now,
        );
        final overlayId = await _overlayBoxRepository!.createOverlayBox(overlayBox);
        debugPrint('ViewerScreen: Created overlay box $i with id: $overlayId');
      }

      debugPrint('ViewerScreen: Successfully saved ${_translations.length} overlay boxes');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translations saved to database!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Reload translations to ensure UI is in sync
      await _loadTranslations();
    } catch (e, stackTrace) {
      debugPrint('ViewerScreen: Error saving translations: $e');
      debugPrint('ViewerScreen: Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving translations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteSelectedBox() {
    if (_selectedBoxIndex != null && _isEditMode) {
      setState(() {
        _translations.removeAt(_selectedBoxIndex!);
        _selectedBoxIndex = null;
      });
    }
  }

  /// Perform OCR for a specific box
  Future<void> _performOcrForBox(int boxIndex) async {
    // Early exit if widget is disposed or conditions not met
    if (!mounted || _ocrService == null || _imageSize == null || _isProcessingOcr) {
      return;
    }

    if (boxIndex < 0 || boxIndex >= _translations.length) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isProcessingOcr = true;
    });

    try {
      final translation = _translations[boxIndex];
      final boxRect = Rect.fromLTRB(
        translation.left,
        translation.top,
        translation.right,
        translation.bottom,
      );

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Processing OCR...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Perform OCR - try Chinese model first for better vertical text support
      String? recognizedText = await _ocrService!.recognizeText(
        _currentImageFile,
        boxRect,
        _imageSize!,
        useChinese: true,  // Use Chinese model for better vertical text detection
      );
      
      if (!mounted) return; // Check again after async operation
      
      if (recognizedText == null || recognizedText.isEmpty) {
        recognizedText = await _ocrService!.recognizeText(
          _currentImageFile,
          boxRect,
          _imageSize!,
          useChinese: false,  // Fallback to Japanese model
        );
      }

      if (!mounted) return; // Check again after async operation

      if (recognizedText != null && recognizedText.isNotEmpty) {
        // Update translation text
        final textToUse = recognizedText!; // Non-null assertion since we checked above
        setState(() {
          _translations[boxIndex] = Translation(
            left: translation.left,
            top: translation.top,
            right: translation.right,
            bottom: translation.bottom,
            text: textToUse,
          );
        });

        // Copy to clipboard
        await Clipboard.setData(ClipboardData(text: textToUse));

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Text recognized and copied to clipboard!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // No text detected
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No text detected in selected area'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('OCR error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingOcr = false;
        });
      }
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
    // Use ACTUAL offset/size for consistency with RectanglePainter
    final effectiveOffset = _actualImageOffset ?? _imageOffset;
    final effectiveSize = _actualImageSize ?? _displayedImageSize;
    
    if (effectiveOffset == null || effectiveSize == null) return Rect.zero;
    
    // Convert relative coordinates (0-1) to absolute screen coordinates
    return Rect.fromLTRB(
      effectiveOffset.dx + (t.left * effectiveSize.width),
      effectiveOffset.dy + (t.top * effectiveSize.height),
      effectiveOffset.dx + (t.right * effectiveSize.width),
      effectiveOffset.dy + (t.bottom * effectiveSize.height),
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
    if (_selectedBoxIndex == null || _resizeHandle == null) return;

    // Use ACTUAL offset/size for consistency
    final effectiveOffset = _actualImageOffset ?? _imageOffset;
    final effectiveSize = _actualImageSize ?? _displayedImageSize;
    
    if (effectiveOffset == null || effectiveSize == null) return;

    final translation = _translations[_selectedBoxIndex!];
    
    final oldImagePos = Offset(
      (_dragStart!.dx - effectiveOffset.dx) / effectiveSize.width,
      (_dragStart!.dy - effectiveOffset.dy) / effectiveSize.height,
    );
    
    final newImagePos = Offset(
      (newPosition.dx - effectiveOffset.dx) / effectiveSize.width,
      (newPosition.dy - effectiveOffset.dy) / effectiveSize.height,
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
    if (_selectedBoxIndex == null) return;

    // Use ACTUAL offset/size for consistency
    final effectiveOffset = _actualImageOffset ?? _imageOffset;
    final effectiveSize = _actualImageSize ?? _displayedImageSize;
    
    if (effectiveOffset == null || effectiveSize == null) return;

    final translation = _translations[_selectedBoxIndex!];
    
    final dx = (newPosition.dx - _dragStart!.dx) / effectiveSize.width;
    final dy = (newPosition.dy - _dragStart!.dy) / effectiveSize.height;

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