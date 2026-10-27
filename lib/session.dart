import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';

/// The level assumed when a position carries no floor, as GPS fixes do: the ground floor.
const defaultLevel = 0.0;

/// The app's SDK instance and what it reported last, for the tabs to show.
class SdkSession extends ChangeNotifier {
  SdkSession({required this.token, this.apiBaseUrl});

  final String token;
  final Uri? apiBaseUrl;

  Proximiio? sdk;
  ProximiioState state = ProximiioState.idle;
  PermissionStatus? permissions;
  ProximiioApplication? application;
  String? visitorId;
  PositionUpdate? position;
  ProximiioFloor? floor;
  List<ProximiioFloor> floors = const [];
  final Map<String, ProximiioGeofence> geofencesInside = {};
  final List<String> events = [];
  String? error;
  bool busy = false;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  Map<String, ProximiioFeature>? _features;
  bool _disposed = false;

  /// Creates the SDK, asks for permissions, authenticates and starts positioning.
  ///
  /// Call it again after a failure; steps that are done already are skipped.
  Future<void> connect() => _run(() async {
    final sdk = this.sdk ?? await _create();
    final permissions = await sdk.requestPermissions();
    _update(() => this.permissions = permissions);
    if (!permissions.isLocationAuthorized) {
      throw const _Failure('Allow location access to see your position, then tap Start.');
    }
    // The highAccuracy preset fuses PDR, which needs motion; without it positions still arrive.
    await sdk.requestMotionPermission();
    if (await sdk.state() == ProximiioState.idle) {
      final application = await sdk.authenticate();
      final visitorId = await sdk.visitorId();
      _update(() {
        this.application = application;
        this.visitorId = visitorId;
      });
    }
    // Routes work from the stored path network at once; the download below refreshes it.
    await sdk.loadCachedRouteNetwork();
    await sdk.start();
    try {
      await sdk.loadRouteNetwork();
    } on ProximiioException catch (error) {
      _log('Route network refresh failed: ${error.code.name}');
    }
    await _loadFloors(sdk);
  });

  /// The floor the visitor is on, as the SDK reports it.
  ProximiioFloor? get reportedFloor => floor ?? position?.floor;

  /// The floor to show and route from: the reported one, else the venue's floor at [defaultLevel].
  ProximiioFloor? get currentFloor => reportedFloor ?? floors.where((floor) => floor.level == defaultLevel).firstOrNull;

  /// The level to route from.
  double get level => reportedFloor?.level ?? defaultLevel;

  /// Stops positioning. [connect] starts it again.
  Future<void> stop() => _run(() async {
    await sdk?.stop();
  });

  /// The venue feature with [id], from the features the SDK stored.
  Future<ProximiioFeature?> feature(String id) async {
    final sdk = this.sdk;
    if (sdk == null) return null;
    final features = _features ??= {for (final feature in await sdk.features()) feature.id: feature};
    return features[id];
  }

  Future<Proximiio> _create() async {
    // highAccuracy: a position every second and PDR between beacon positions, at the cost of battery.
    final sdk = await Proximiio.create(
      ProximiioConfiguration(token: token, apiBaseUrl: apiBaseUrl, preset: ConfigurationPreset.highAccuracy),
    );
    _update(() => this.sdk = sdk);
    _subscriptions.addAll([
      sdk.stateChanges.listen((state) => _update(() => this.state = state)),
      sdk.permissionUpdates.listen((status) => _update(() => permissions = status)),
      sdk.positions.listen((position) => _update(() => this.position = position)),
      sdk.floorChanges.listen((change) {
        _update(() => floor = change.floor);
        _log('Floor ${floorName(change.previousFloor)} → ${floorName(change.floor)}');
      }),
      sdk.geofenceEvents.listen((event) {
        switch (event) {
          case GeofenceEntered(:final geofence):
            geofencesInside[geofence.id] = geofence;
            _log('Entered ${geofence.name ?? geofence.id}');
          case GeofenceExited(:final geofence, :final dwellTime):
            geofencesInside.remove(geofence.id);
            _log('Left ${geofence.name ?? geofence.id} after ${dwellTime.inSeconds} s');
          case PrivacyZoneEntered(:final zone):
            _log('Entered privacy zone ${zone.name ?? zone.id}; positions are withheld');
          case PrivacyZoneExited(:final zone):
            _log('Left privacy zone ${zone.name ?? zone.id}');
        }
      }),
      sdk.venueDataChanges.listen((change) {
        if (change.contains(VenueDataKind.features)) _features = null;
        if (change.contains(VenueDataKind.floors)) unawaited(_loadFloors(sdk));
      }),
    ]);
    final visitorId = await sdk.visitorId();
    _update(() => this.visitorId = visitorId);
    return sdk;
  }

  Future<void> _loadFloors(Proximiio sdk) async {
    try {
      final floors = await sdk.floors();
      _update(() => this.floors = floors);
    } on ProximiioException catch (error) {
      _log('Loading the floors failed: ${error.code.name}');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    _update(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on ProximiioException catch (failure) {
      _update(() => error = failure.message == null ? failure.code.name : '${failure.code.name}: ${failure.message}');
    } on _Failure catch (failure) {
      _update(() => error = failure.message);
    } finally {
      _update(() => busy = false);
    }
  }

  void _log(String line) {
    _update(() {
      events.insert(0, '${clock(DateTime.now())}  $line');
      if (events.length > 30) events.removeLast();
    });
  }

  void _update(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}

/// The floor's name, or its level when it has none.
String floorName(ProximiioFloor? floor) => floor == null ? '-' : floor.name ?? 'level ${floor.level}';

/// [time] in local time as `HH:mm:ss`.
String clock(DateTime time) {
  final local = time.toLocal();
  return [local.hour, local.minute, local.second].map((part) => '$part'.padLeft(2, '0')).join(':');
}

class _Failure implements Exception {
  const _Failure(this.message);

  final String message;
}
