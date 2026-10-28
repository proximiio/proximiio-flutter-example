import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'session.dart';

/// A Proximi.io wayfinding web app in one web view for the app's life, fed with the SDK's positions and the
/// direction of walking, and told which destination to show.
///
/// The app talks to the web app with messages on `window` (the README lists them):
/// - `SET_LOCATION` with `latitude`, `longitude` and `level`. The web app ignores one without a level and
///   handles at most one every 3 seconds.
/// - `SET_HEADING` with `heading` in degrees from north, taken at once.
/// - `SET_DESTINATION` with the place's `id`: the web app shows the place and centres on it.
///
/// The web app handles messages only once its map is loaded, and drops them before. It is created when the
/// app starts, so it is usually ready by the time someone taps "Take me there".
class Wayfinding {
  Wayfinding({required this.session, required Uri url}) : web = WebViewController() {
    web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('ProximiioHost', onMessageReceived: _onWebMessage)
      ..loadRequest(url);
    session.addListener(_onSession);
    // The web app drops positions until its map is ready, and a phone standing still may report no new
    // one, so the last position and direction are sent again every 3 seconds.
    _resend = Timer.periodic(const Duration(seconds: 3), (_) {
      _sendPosition();
      _sendHeading();
    });
  }

  final SdkSession session;
  final WebViewController web;
  late final Timer _resend;
  PositionUpdate? _sent;
  double? _sentHeading;

  ProximiioFeature? _destination;
  Timer? _destinationRetry;
  int _destinationTries = 0;
  bool _deliveringDestination = false;

  /// Shows [place] as the destination in the web app, as soon as the web app can take it.
  void showDestination(ProximiioFeature place) {
    _destination = place;
    _destinationTries = 0;
    _destinationRetry?.cancel();
    _destinationRetry = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_deliverDestination()));
    unawaited(_deliverDestination());
  }

  /// Sends the destination until the web app shows it. The web app says nothing back yet, so the check is
  /// its panel heading, which is the place's title; after 30 tries it gives up.
  Future<void> _deliverDestination() async {
    final place = _destination;
    if (place == null || _deliveringDestination) return;
    _deliveringDestination = true;
    try {
      if (_destinationTries > 0 && await _showsHeading(place.title()) || ++_destinationTries > 30) {
        _destinationDelivered();
        return;
      }
      // `start: current` asks the web app to route from the visitor's position. The web app ignores it until it
      // supports it, and the visitor taps "Take me there" in the web app.
      _post({'type': 'SET_DESTINATION', 'id': place.id, 'start': 'current'});
    } finally {
      _deliveringDestination = false;
    }
  }

  void _destinationDelivered() {
    _destinationRetry?.cancel();
    _destinationRetry = null;
    _destination = null;
  }

  Future<bool> _showsHeading(String? title) async {
    if (title == null) return true;
    try {
      final shown = await web.runJavaScriptReturningResult(
        '[...document.querySelectorAll("h1")].some((h) => h.textContent.trim() === ${jsonEncode(title)})',
      );
      return '$shown' == 'true' || '$shown' == '1';
    } on Object {
      return false;
    }
  }

  /// Messages the web app sends on the `ProximiioHost` channel, once it supports them: `MAP_READY` when its map
  /// is loaded, `DESTINATION_SET` or `DESTINATION_NOT_FOUND` after a `SET_DESTINATION`.
  void _onWebMessage(JavaScriptMessage message) {
    final Object? decoded;
    try {
      decoded = jsonDecode(message.message);
    } on FormatException {
      return;
    }
    switch (decoded) {
      case {'type': 'MAP_READY'}:
        _sendPosition();
        _sendHeading();
        if (_destination != null) {
          _destinationTries = 0;
          unawaited(_deliverDestination());
        }
      case {'type': 'DESTINATION_SET' || 'DESTINATION_NOT_FOUND'}:
        _destinationDelivered();
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
    // The web app ignores a heading of 0, so north goes as 360.
    _post({'type': 'SET_HEADING', 'heading': heading == 0 ? 360.0 : heading});
  }

  void _post(Map<String, Object> message) =>
      unawaited(web.runJavaScript('window.postMessage(${jsonEncode(message)}, "*");').onError<Object>((_, _) {}));

  void dispose() {
    _resend.cancel();
    _destinationRetry?.cancel();
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
