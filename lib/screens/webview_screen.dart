import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

class WebViewScreen extends StatefulWidget {
  final String initialUrl;
  final String? title;

  const WebViewScreen({
    super.key,
    required this.initialUrl,
    this.title,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  String _currentUrl = '';
  bool _canGoBack = false;
  bool _canGoForward = false;
  double _progress = 0;
  String? _errorMessage;
  bool _showOAuthWarning = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
  }

  @override
  void dispose() {
    // Don't dispose WebView controller here - let it handle its own lifecycle
    // Just clear the reference
    _webViewController = null;
    super.dispose();
  }

  Future<void> _updateNavigationState() async {
    if (_webViewController != null) {
      final canGoBack = await _webViewController!.canGoBack();
      final canGoForward = await _webViewController!.canGoForward();
      if (mounted) {
        setState(() {
          _canGoBack = canGoBack;
          _canGoForward = canGoForward;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if platform is available
    try {
      return Scaffold(
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title ?? 'Web Browser'),
              if (_currentUrl.isNotEmpty)
                Text(
                  _currentUrl,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: _isLoading
                ? LinearProgressIndicator(value: _progress > 0 ? _progress : null)
                : const SizedBox.shrink(),
          ),
          actions: [
            // Open in external browser button (always visible)
            IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: () async {
                try {
                  final urlToOpen = _currentUrl.isNotEmpty ? _currentUrl : widget.initialUrl;
                  await launchUrl(
                    Uri.parse(urlToOpen),
                    mode: LaunchMode.externalApplication,
                  );
                } catch (e) {
                  debugPrint('Error opening in browser: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Không thể mở trình duyệt. Vui lòng thử lại.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              tooltip: 'Mở trong trình duyệt',
            ),
            // Navigation buttons
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _canGoBack ? () async {
                await _webViewController?.goBack();
                _updateNavigationState();
              } : null,
              tooltip: 'Back',
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _canGoForward ? () async {
                await _webViewController?.goForward();
                _updateNavigationState();
              } : null,
              tooltip: 'Forward',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                try {
                  await _webViewController?.reload();
                } catch (e) {
                  debugPrint('Error reloading WebView: $e');
                  // If reload fails, try loading the current URL again
                  if (_webViewController != null && mounted) {
                    try {
                      await _webViewController!.loadUrl(
                        urlRequest: URLRequest(url: WebUri(_currentUrl.isNotEmpty ? _currentUrl : widget.initialUrl)),
                      );
                    } catch (e2) {
                      debugPrint('Error loading URL: $e2');
                    }
                  }
                }
              },
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () async {
                try {
                  await _webViewController?.loadUrl(
                    urlRequest: URLRequest(url: WebUri(widget.initialUrl)),
                  );
                } catch (e) {
                  debugPrint('Error loading home URL: $e');
                }
              },
              tooltip: 'Home',
            ),
          ],
        ),
        body: Column(
          children: [
            // OAuth warning banner
            if (_showOAuthWarning)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Lưu ý: Login với X có thể gây crash. Nếu gặp vấn đề, hãy dùng nút "Mở trong trình duyệt" ở góc trên.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() {
                          _showOAuthWarning = false;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            // WebView content or error
            Expanded(
              child: _errorMessage != null
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Lỗi WebView',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        setState(() {
                          _errorMessage = null;
                        });
                        try {
                          if (_webViewController != null && mounted) {
                            await _webViewController!.loadUrl(
                              urlRequest: URLRequest(url: WebUri(_currentUrl.isNotEmpty ? _currentUrl : widget.initialUrl)),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error retrying: $e');
                          // If WebView is disposed, we need to rebuild
                          if (mounted) {
                            setState(() {
                              _errorMessage = 'WebView đã bị đóng. Vui lòng quay lại và mở lại.';
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
                  )
                : InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(widget.initialUrl),
                  headers: {
                    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                    'Accept-Language': 'en-US,en;q=0.9',
                    'Accept-Encoding': 'gzip, deflate, br',
                    'DNT': '1',
                    'Connection': 'keep-alive',
                    'Upgrade-Insecure-Requests': '1',
                  },
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  transparentBackground: false,
                  // OAuth/Login support
                  thirdPartyCookiesEnabled: true,
                  cacheEnabled: true,
                  clearCache: false,
                  // Support for popup windows (needed for OAuth)
                  supportMultipleWindows: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  // Security settings
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  // User agent - use latest Chrome to avoid bot detection
                  userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  debugPrint('WebView created');
                },
                onLoadStart: (controller, url) {
                  debugPrint('WebView load start: $url');
                  final urlString = url.toString();
                  // Check if we're on OAuth/login pages
                  final isOAuthPage = urlString.contains('oauth') || 
                                      urlString.contains('authorize') || 
                                      urlString.contains('accounts.x.ai') ||
                                      urlString.contains('x.com/i/oauth');
                  
                  if (mounted) {
                    setState(() {
                      _isLoading = true;
                      _currentUrl = urlString;
                      _progress = 0;
                      _errorMessage = null;
                      _showOAuthWarning = isOAuthPage;
                    });
                  }
                },
                onLoadStop: (controller, url) async {
                  debugPrint('WebView load stop: $url');
                  if (mounted) {
                    setState(() {
                      _isLoading = false;
                      _currentUrl = url.toString();
                      _progress = 1.0;
                      _errorMessage = null;
                    });
                    _updateNavigationState();
                  }
                },
                onProgressChanged: (controller, progress) {
                  if (mounted) {
                    setState(() {
                      _progress = progress / 100;
                    });
                  }
                },
                onReceivedError: (controller, request, error) {
                  debugPrint('WebView error: ${error.description} (code: ${error.type}) for ${request.url}');
                  // Don't show error for OAuth redirects or if we're in the middle of navigation
                  // Only show error if it's a real network error and we're not loading
                  if (mounted && error.type != WebResourceErrorType.HOST_LOOKUP && !_isLoading) {
                    // Check if URL is part of OAuth flow - don't show error for those
                    final url = request.url?.toString() ?? '';
                    if (!url.contains('oauth') && !url.contains('authorize') && !url.contains('accounts.x.ai')) {
                      setState(() {
                        _errorMessage = 'Lỗi tải trang: ${error.description}';
                        _isLoading = false;
                      });
                    }
                  }
                },
                onReceivedHttpError: (controller, request, response) {
                  final statusCode = response.statusCode;
                  debugPrint('WebView HTTP error: $statusCode - ${response.reasonPhrase} for ${request.url}');
                  // Don't show error for redirects (3xx) as they're normal for OAuth
                  // Also, 403 might be temporary or part of redirect flow, so don't show immediately
                  if (statusCode != null && statusCode >= 400 && statusCode != 403 && mounted) {
                    setState(() {
                      _errorMessage = 'HTTP Error $statusCode: ${response.reasonPhrase ?? "Unknown error"}';
                    });
                  } else if (statusCode == 403 && mounted) {
                    // For 403, wait a bit to see if it's just a redirect
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted && _isLoading == false && _errorMessage == null) {
                        // If still on error page after 2 seconds, show error
                        setState(() {
                          _errorMessage = 'HTTP 403: Truy cập bị từ chối. Có thể do bot detection.';
                        });
                      }
                    });
                  }
                },
                // Handle popup windows (needed for OAuth login)
                onCreateWindow: (controller, createWindowAction) async {
                  debugPrint('WebView create window: ${createWindowAction.request.url}');
                  // Open popup in same window (OAuth redirects)
                  await controller.loadUrl(urlRequest: createWindowAction.request);
                  return true;
                },
                // Handle console messages for debugging
                onConsoleMessage: (controller, consoleMessage) {
                  // Only log important errors, not all console messages
                  if (consoleMessage.messageLevel == ConsoleMessageLevel.ERROR) {
                    debugPrint('WebView console ERROR: ${consoleMessage.message}');
                    // If we see JavaScript errors during OAuth, it might cause issues
                    // But we can't prevent the crash from native side
                  }
                },
                // Handle SSL errors
                onReceivedServerTrustAuthRequest: (controller, challenge) async {
                  // Accept all certificates for OAuth flows
                  return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                },
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      // Fallback if WebView is not available
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title ?? 'Web Browser'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'WebView không khả dụng',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vui lòng khởi động lại ứng dụng (full restart, không phải hot reload).\n'
                'Nếu vẫn lỗi, có thể cần cài đặt WebView2 Runtime trên Windows.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  // Open in external browser as fallback
                  await launchUrl(Uri.parse(widget.initialUrl));
                },
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Mở trong trình duyệt'),
              ),
            ],
          ),
        ),
      );
    }
  }
}

