import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:web2wave/web2wave.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Web2WaveWebScreen extends StatefulWidget {
  static const Color defaultBackgroundColor = Color(0xFF0F0F0F);

  final String url;
  final bool allowBackNavigation;
  final Web2WaveWebListener? listener;
  final Color backgroundColor;
  final Color? loadingOverlayColor;
  final Widget? loadingIndicator;

  const Web2WaveWebScreen({
    super.key,
    required this.url,
    required this.allowBackNavigation,
    this.listener,
    this.backgroundColor = defaultBackgroundColor,
    this.loadingOverlayColor,
    this.loadingIndicator,
  });

  @override
  State<Web2WaveWebScreen> createState() => _Web2WaveWebScreenState();
}

class _Web2WaveWebScreenState extends State<Web2WaveWebScreen> {
  late final WebViewController _controller;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setBackgroundColor(widget.backgroundColor)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            setState(() {
              _isLoaded = true;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final data = jsonDecode(message.message);
          _handleJsMessage(data);
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _handleJsMessage(Map<String, dynamic> data) {
    final event = data['event'];
    final eventData = data['data'];

    if (event == 'Quiz finished') {
      widget.listener?.onQuizFinished(eventData);
    } else if (event == 'Close webview') {
      widget.listener?.onClose(eventData);
    } else {
      widget.listener?.onEvent(event: event, data: eventData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (b, r) async {
        if (widget.allowBackNavigation) {
          final canGoBack = await _controller.canGoBack();
          if (canGoBack) {
            _controller.goBack();
          } else {
            widget.listener?.onClose({});
          }
        }
      },
      child: Stack(
        children: [
          if (Platform.isIOS && widget.allowBackNavigation)
            GestureDetector(
              onHorizontalDragUpdate: (details) async {
                if (details.globalPosition.dx < 150 && details.delta.dx > 0) {
                  final canGoBack = await _controller.canGoBack();
                  if (canGoBack) {
                    _controller.goBack();
                  } else {
                    widget.listener?.onClose({});
                  }
                }
              },
              child: ColoredBox(
                color: widget.backgroundColor,
                child: WebViewWidget(controller: _controller),
              ),
            )
          else
            ColoredBox(
              color: widget.backgroundColor,
              child: WebViewWidget(controller: _controller),
            ),
          if (!_isLoaded)
            Positioned.fill(
              child: Container(
                color: widget.loadingOverlayColor ??
                    widget.backgroundColor.withOpacity(0.9),
                alignment: Alignment.center,
                child:
                    widget.loadingIndicator ?? const CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
