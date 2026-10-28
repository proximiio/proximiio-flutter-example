import 'package:flutter/material.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';

import 'session.dart';

/// The venue's places in the app's own screens, as an exhibitor list would show them. A place's details
/// have "Take me there", which opens the wayfinding web app on it.
class PlacesTab extends StatefulWidget {
  const PlacesTab({super.key, required this.session, required this.onTakeMeThere});

  final SdkSession session;

  /// Opens the web app on the place; `null` when the app has no web app to open.
  final void Function(ProximiioFeature place)? onTakeMeThere;

  @override
  State<PlacesTab> createState() => _PlacesTabState();
}

class _PlacesTabState extends State<PlacesTab> {
  Future<List<ProximiioFeature>>? _places;
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    _onSession();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSession);
    super.dispose();
  }

  /// The venue data is there once the SDK has authenticated, so the list loads then.
  void _onSession() {
    if (_places == null && widget.session.application != null) _reload();
  }

  void _reload() => setState(() => _places = widget.session.places());

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search places'),
          onChanged: (query) => setState(() => _query = query.trim().toLowerCase()),
        ),
      ),
      Expanded(
        child: FutureBuilder(
          future: _places,
          builder: (context, snapshot) {
            if (_places == null) return const Center(child: Text('The places load once the SDK has started.'));
            if (snapshot.hasError) return Center(child: Text('Loading the places failed: ${snapshot.error}'));
            final places = snapshot.data;
            if (places == null) return const Center(child: CircularProgressIndicator());
            final shown = [
              for (final place in places)
                if (place.title()!.toLowerCase().contains(_query)) place,
            ];
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _places;
              },
              child: ListView.builder(
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final place = shown[index];
                  return ListTile(
                    title: Text(place.title()!),
                    subtitle: Text(_floor(place)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showDetails(place),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );

  String _floor(ProximiioFeature place) {
    final level = place.level;
    if (level == null) return 'No floor';
    final floor = widget.session.floors.where((floor) => floor.level == level).firstOrNull;
    return floor?.name ?? 'Level ${level.round()}';
  }

  /// The place's own screen, where an app would show an exhibitor's details.
  void _showDetails(ProximiioFeature place) {
    final onTakeMeThere = widget.onTakeMeThere;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(place.title()!, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(_floor(place)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onTakeMeThere == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onTakeMeThere(place);
                    },
              icon: const Icon(Icons.directions_walk),
              label: const Text('Take me there'),
            ),
            if (onTakeMeThere == null) ...[
              const SizedBox(height: 8),
              const Text('No wayfinding URL. Set PROXIMIIO_WAYFINDING_URL in env.json.'),
            ],
          ],
        ),
      ),
    );
  }
}
