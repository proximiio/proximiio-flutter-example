import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';

import 'diagnostics_tab.dart';
import 'map_tab.dart';
import 'places_tab.dart';
import 'session.dart';
import 'status_tab.dart';
import 'web_tab.dart';

/// The application token comes from the build, never from source:
///   cp env.example.json env.json   # put your token in env.json (gitignored)
///   flutter run --dart-define-from-file=env.json
const _token = String.fromEnvironment('PROXIMIIO_TOKEN');
const _apiBaseUrl = String.fromEnvironment('PROXIMIIO_API_BASE_URL');

/// The Proximi.io wayfinding web app of the Web tab.
const _wayfindingUrl = String.fromEnvironment('PROXIMIIO_WAYFINDING_URL');

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Proximi.io example',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF3F69FF)),
    home: _token.isEmpty ? const _NoTokenPage() : const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _session = SdkSession(token: _token, apiBaseUrl: _apiBaseUrl.isEmpty ? null : Uri.parse(_apiBaseUrl));
  late final Wayfinding? _wayfinding;
  int _tab = 0;
  bool _mapOpened = false;

  static const _webTab = 3;
  static const _diagnosticsTab = 4;

  @override
  void initState() {
    super.initState();
    unawaited(_session.connect());
    // The web app loads at once, so it is ready when "Take me there" opens it.
    _wayfinding = _wayfindingUrl.isEmpty ? null : Wayfinding(session: _session, url: Uri.parse(_wayfindingUrl));
  }

  @override
  void dispose() {
    _wayfinding?.dispose();
    _session.dispose();
    super.dispose();
  }

  void _takeMeThere(ProximiioFeature place) {
    setState(() => _tab = _webTab);
    _wayfinding?.showDestination(place);
  }

  @override
  Widget build(BuildContext context) {
    final wayfinding = _wayfinding;
    return Scaffold(
      appBar: AppBar(title: const Text('Proximi.io example')),
      // The native map is created when its tab is first opened and then kept.
      body: IndexedStack(
        index: _tab,
        children: [
          StatusTab(session: _session),
          PlacesTab(session: _session, onTakeMeThere: wayfinding == null ? null : _takeMeThere),
          if (_mapOpened) MapTab(session: _session) else const SizedBox.shrink(),
          if (wayfinding == null)
            const _Notice('No wayfinding URL. Set PROXIMIIO_WAYFINDING_URL in env.json.')
          else
            WebTab(wayfinding: wayfinding),
          DiagnosticsTab(session: _session, active: _tab == _diagnosticsTab),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() {
          _tab = tab;
          _mapOpened |= tab == 2;
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.my_location), label: 'Position'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Places'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.public), label: 'Web'),
          NavigationDestination(icon: Icon(Icons.troubleshoot), label: 'Diagnostics'),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(24), child: Text(text));
}

class _NoTokenPage extends StatelessWidget {
  const _NoTokenPage();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Proximi.io example')),
    body: const _Notice(
      'No token. Copy env.example.json to env.json, put your Proximi.io token in it, '
      'and run with --dart-define-from-file=env.json.',
    ),
  );
}
