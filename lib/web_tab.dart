import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'session.dart';

/// A Proximi.io wayfinding web app in one web view for the app's life, fed with the SDK's positions and the
/// direction of walking, and told which destination to route to.
///
/// The app talks to the web app with messages on `window` (the README lists them):
/// - `SET_LOCATION` with `latitude`, `longitude` and `level`. The web app ignores one without a level.
/// - `SET_HEADING` with `heading` in degrees from north.
/// - `SET_DESTINATION` with the place's `id` and `start: current`: the web app routes from the visitor's
///   position to the place.
///
/// The web app answers on the `ProximiioHost` JavaScript channel: `MAP_READY` once its map is loaded, then
/// `DESTINATION_SET` or `DESTINATION_NOT_FOUND` for each destination. It keeps what arrives before it is ready
/// and handles it then. The web view is created when the app starts, so the map is usually ready by the time
/// someone taps "Take me there".
class Wayfinding {
  Wayfinding({required this.session, required Uri url, this.onDestinationNotFound}) : web = WebViewController() {
    web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageStarted: (_) => _ready = false))
      ..addJavaScriptChannel('ProximiioHost', onMessageReceived: _onWebMessage)
      ..loadRequest(url);
    session.addListener(_onSession);
    // A phone standing still may report no new position, and the web app may reload, so the last position
    // and direction are sent again every 3 seconds.
    _resend = Timer.periodic(const Duration(seconds: 3), (_) {
      _sendPosition();
      _sendHeading();
    });
  }

  final SdkSession session;
  final WebViewController web;

  /// Called when the web app has no place with the id "Take me there" sent.
  final void Function(ProximiioFeature place)? onDestinationNotFound;

  late final Timer _resend;
  PositionUpdate? _sent;
  double? _sentHeading;

  /// Whether the web app said `MAP_READY` since its page last loaded.
  bool _ready = false;

  /// The place sent last, until the web app answers for it.
  ProximiioFeature? _destination;

  /// Routes from the visitor's position to [place] in the web app, at once or when its map is ready.
  void showDestination(ProximiioFeature place) {
    _destination = place;
    if (_ready) _sendDestination();
  }

  void _sendDestination() {
    final place = _destination;
    if (place != null) _post({'type': 'SET_DESTINATION', 'id': place.id, 'start': 'current'});
  }

  void _onWebMessage(JavaScriptMessage message) {
    final Object? decoded;
    try {
      decoded = jsonDecode(message.message);
    } on FormatException {
      return;
    }
    switch (decoded) {
      case {'type': 'MAP_READY'}:
        _ready = true;
        _sendPosition();
        _sendHeading();
        _sendDestination();
      case {'type': 'DESTINATION_SET', 'id': final String id} when id == _destination?.id:
        _destination = null;
      case {'type': 'DESTINATION_NOT_FOUND', 'id': final String id} when id == _destination?.id:
        final place = _destination!;
        _destination = null;
        onDestinationNotFound?.call(place);
    }
  }

  void _onSession() {
    if (!identical(session.position, _sent)) _sendPosition();
    if (session.heading != _sentHeading) _sendHeading();
  }

  void _sendPosition() {
    final position = session.position;
    if (position == null || session.state != ProximiioState.running) return;
    _sent = position;
    _post({
      'type': 'SET_LOCATION',
      'latitude': position.coordinate.latitude,
      'longitude': position.coordinate.longitude,
      'level': session.level,
    });
  }

  /// The direction turns the marker of a position, so it follows the first position.
  void _sendHeading() {
    final heading = session.heading;
    if (heading == null || _sent == null || session.state != ProximiioState.running) return;
    _sentHeading = heading;
    _post({'type': 'SET_HEADING', 'heading': heading});
  }

  void _post(Map<String, Object> message) =>
      unawaited(web.runJavaScript('window.postMessage(${jsonEncode(message)}, "*");').onError<Object>((_, _) {}));

  void dispose() {
    _resend.cancel();
    session.removeListener(_onSession);
  }
}

/// The Web tab: the wayfinding web app.
class WebTab extends StatelessWidget {
  const WebTab({super.key, required this.wayfinding});

  final Wayfinding wayfinding;

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: wayfinding.web);
}
