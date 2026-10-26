import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:flutter_proximiio_map/flutter_proximiio_map.dart';

import 'session.dart';

/// The venue map. Tap a place to see its name and route to it.
class MapTab extends StatefulWidget {
  const MapTab({super.key, required this.session});

  final SdkSession session;

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  ProximiioMapController? _map;
  StreamSubscription<MapFeatureTap>? _taps;
  String? _route;

  void _onMapCreated(ProximiioMapController map) {
    setState(() => _map = map);
    _taps = map.featureTaps.listen(_onTap);
    // Turn-by-turn guidance along the routes of showRoute.
    unawaited(map.setGuidanceRules(RouteFollowRules.venueWalk));
  }

  Future<void> _onTap(MapFeatureTap tap) async {
    final language = Localizations.localeOf(context).languageCode;
    final features = [for (final id in tap.featureIds) await widget.session.feature(id)].nonNulls;
    final feature = features.where((feature) => feature.title() != null).firstOrNull ?? features.firstOrNull;
    if (feature == null || !mounted) return;
    final title = feature.title(language) ?? feature.id;
    final destination = _pointOf(feature) ?? tap.coordinate;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(title),
          action: SnackBarAction(label: 'Route here', onPressed: () => _routeTo(title, destination, feature.level)),
        ),
      );
  }

  Future<void> _routeTo(String title, Coordinate destination, double? level) async {
    final map = _map;
    final position = widget.session.position;
    if (map == null) return;
    if (position == null) {
      _show('No position yet');
      return;
    }
    try {
      final route = await map.showRoute(
        from: position.coordinate,
        fromLevel: position.floor?.level ?? 0,
        to: destination,
        toLevel: level,
      );
      final minutes = (route.duration.inSeconds / 60).ceil();
      setState(() => _route = '$title · ${route.distanceMeters.round()} m · $minutes min');
    } on ProximiioException catch (error) {
      _show('No route to $title: ${error.noRouteReason?.name ?? error.code.name}');
    } on ProximiioMapException catch (error) {
      // A later showRoute or clearRoute replaced this one.
      if (error.code != MapErrorCode.superseded) _show(error.message ?? error.code.name);
    }
  }

  Future<void> _clearRoute() async {
    setState(() => _route = null);
    await _map?.clearRoute();
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.session,
    // The map needs the SDK instance from Proximiio.create; it follows its stop() and start().
    builder:
        (context, map) =>
            widget.session.sdk == null ? Center(child: Text(widget.session.error ?? 'Starting the SDK…')) : map!,
    child: Column(
      children: [
        Expanded(
          child: ProximiioMap(
            options: const MapOptions(floorSelector: FloorSelectorPosition.trailing),
            onMapCreated: _onMapCreated,
          ),
        ),
        if (_map case final map?) _MapPanel(map: map, route: _route, onClearRoute: _clearRoute),
      ],
    ),
  );
}

class _MapPanel extends StatelessWidget {
  const _MapPanel({required this.map, required this.route, required this.onClearRoute});

  final ProximiioMapController map;
  final String? route;
  final VoidCallback onClearRoute;

  @override
  Widget build(BuildContext context) {
    final route = this.route;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([map.floors, map.selectedFloor]),
            builder: (context, _) {
              final selected = map.selectedFloor.value;
              final name = map.floors.value.where((floor) => floor.level == selected.level).firstOrNull?.name;
              return Text('Floor ${name ?? selected.level}${selected.isPinned ? ' (chosen)' : ''}');
            },
          ),
          if (route == null)
            const Text('Tap a place to route to it.')
          else ...[
            Text(route, style: Theme.of(context).textTheme.titleSmall),
            ValueListenableBuilder(
              valueListenable: map.guidance,
              builder:
                  (context, guidance, _) => Text(
                    guidance == null
                        ? 'Waiting for guidance…'
                        : guidance.hasArrived
                        ? 'You have arrived.'
                        : guidance.text ?? '${guidance.remainingMeters.round()} m to go',
                  ),
            ),
          ],
          ValueListenableBuilder(
            valueListenable: map.lastError,
            builder:
                (context, error, _) =>
                    error == null
                        ? const SizedBox.shrink()
                        : Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(onPressed: () => map.recentre(), child: const Text('Recentre')),
              OutlinedButton(onPressed: () => map.showVenue(), child: const Text('Whole venue')),
              if (route != null) FilledButton.tonal(onPressed: onClearRoute, child: const Text('Clear route')),
            ],
          ),
        ],
      ),
    );
  }
}

/// The coordinate of a point feature, such as a POI.
Coordinate? _pointOf(ProximiioFeature feature) {
  final geometry = feature.geometry;
  if (geometry?['type'] != 'Point') return null;
  final coordinates = geometry?['coordinates'];
  if (coordinates is! List || coordinates.length < 2 || coordinates[0] is! num || coordinates[1] is! num) return null;
  return Coordinate(latitude: (coordinates[1] as num).toDouble(), longitude: (coordinates[0] as num).toDouble());
}
