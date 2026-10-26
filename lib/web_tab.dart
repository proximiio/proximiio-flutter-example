import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'session.dart';

/// A Proximi.io wayfinding web app in a web view, fed with the SDK's positions.
///
/// The web app takes a position as a `SET_LOCATION` message on `window` with `latitude`, `longitude` and
/// `level`. It ignores a message without a level, and it handles at most one message every 3 seconds.
class WebTab extends StatefulWidget {
  const WebTab({super.key, required this.session, required this.url});

  final SdkSession session;
  final Uri url;

  @override
  State<WebTab> createState() => _WebTabState();
}

class _WebTabState extends State<WebTab> {
  late final WebViewController _web;
  late final Timer _resend;
  PositionUpdate? _sent;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(widget.url);
    widget.session.addListener(_onSession);
    // The web app drops positions until its map is ready, and a phone standing still may report no new
    // one, so the last position is sent again every 3 seconds.
    _resend = Timer.periodic(const Duration(seconds: 3), (_) => _send());
  }

  void _onSession() {
    if (!identical(widget.session.position, _sent)) _send();
  }

  void _send() {
    final position = widget.session.position;
    if (position == null || widget.session.state != ProximiioState.running) return;
    _sent = position;
    final message = jsonEncode({
      'type': 'SET_LOCATION',
      'latitude': position.coordinate.latitude,
      'longitude': position.coordinate.longitude,
      'level': widget.session.level,
    });
    unawaited(_web.runJavaScript('window.postMessage($message, "*");').onError<Object>((_, _) {}));
  }

  @override
  void dispose() {
    _resend.cancel();
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}
