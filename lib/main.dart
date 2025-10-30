import 'package:flutter/material.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:flutter_proximiio_map/flutter_proximiio_map.dart';

// Replace this with your Proximiio token
const String token = 'INSERT-PROXIMIIO-TOKEN';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Proximiio Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ProximiioExample(),
    );
  }
}

class ProximiioExample extends StatefulWidget {
  const ProximiioExample({super.key});

  @override
  State<ProximiioExample> createState() => _ProximiioExampleState();
}

class _ProximiioExampleState extends State<ProximiioExample> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _visitorId = '';
  String _status = 'Initializing...';
  ProximiioFloor? _floor;
  ProximiioLocation _location = ProximiioLocation(lat: 0, lng: 0, sourceType: '');
  List<ProximiioGeofence> _geofences = [];
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _requestPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    FlutterProximiio.unsubscribeAll(ProximiioEvents.floorChanged);
    FlutterProximiio.unsubscribeAll(ProximiioEvents.positionUpdated);
    FlutterProximiio.unsubscribeAll(ProximiioEvents.enteredGeofence);
    FlutterProximiio.unsubscribeAll(ProximiioEvents.exitedGeofence);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proximiio Flutter Example'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Data'),
            Tab(icon: Icon(Icons.map), text: 'Map'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe gestures
        children: [
          _buildDataView(),
          _buildMapView(),
        ],
      ),
    );
  }

  Widget _buildDataView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status card
            Card(
              color: _getStatusColor(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Visitor ID
            _buildInfoCard(
              'Visitor Information',
              [
                _buildInfoRow('Visitor ID:', _visitorId.isEmpty ? 'Not connected' : _visitorId),
              ],
            ),
            const SizedBox(height: 16),

            // Location card
            _buildInfoCard(
              'Location',
              [
                _buildInfoRow('Latitude:', _location.lat.toStringAsFixed(8)),
                const SizedBox(height: 8),
                _buildInfoRow('Longitude:', _location.lng.toStringAsFixed(8)),
                const SizedBox(height: 8),
                _buildInfoRow('Accuracy:', _location.accuracy?.toStringAsFixed(2) ?? 'N/A'),
                const SizedBox(height: 8),
                _buildInfoRow('Source:', _location.sourceType ?? 'Unknown'),
                const SizedBox(height: 8),
                _buildInfoRow('Speed:', _location.speed?.toStringAsFixed(2) ?? 'N/A'),
                const SizedBox(height: 8),
                _buildInfoRow('Bearing:', _location.bearing?.toStringAsFixed(2) ?? 'N/A'),
              ],
            ),
            const SizedBox(height: 16),

            // Floor card
            _buildInfoCard(
              'Floor',
              [
                _buildInfoRow('Name:', _floor?.name ?? 'No floor detected'),
                if (_floor != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow('Level:', _floor!.level.toString()),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Geofences card
            _buildInfoCard(
              'Geofences',
              [
                _buildInfoRow(
                  'Current:',
                  _geofences.isEmpty
                    ? 'No geofences'
                    : _geofences.map((g) => g.name).join(', '),
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Count:', _geofences.length.toString()),
              ],
            ),

            if (!_permissionsGranted) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.refresh),
                label: const Text('Request Permissions Again'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    if (!_permissionsGranted || _visitorId.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _permissionsGranted
                ? 'Waiting for Proximiio to initialize...'
                : 'Please grant permissions first',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (!_permissionsGranted) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.lock_open),
                label: const Text('Request Permissions'),
              ),
            ],
          ],
        ),
      );
    }

    return ProximiioMapWidget(
      token: token,
      mapDefaults: {
        'lat': _location.lat != 0 ? _location.lat : 48.1486, // Default location if GPS unavailable
        'lng': _location.lng != 0 ? _location.lng : 17.1077,
        'zoom': 18,
        'pitch': 0,
        'bearing': 0,
      },
      onMapReady: () {
        debugPrint('Map is ready!');
      },
      onMapClick: (data) {
        debugPrint('Map clicked: $data');
      },
      onFeatureClick: (data) {
        debugPrint('Feature clicked: $data');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feature: ${data['title'] ?? 'Unknown'}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  Future<void> _requestPermissions() async {
    print('🔵 Starting permission request...');
    setState(() {
      _status = 'Requesting permissions...';
    });

    try {
      // Request permissions natively through the plugin
      print('🔵 Requesting permissions...');
      await FlutterProximiio.requestPermissions();
      print('🔵 Permissions granted!');

      setState(() {
        _permissionsGranted = true;
        _status = 'Permissions granted';
      });

      print('🔵 Initializing Proximiio...');
      _initProximiio();
    } catch (e) {
      print('🔴 Permission request failed: $e');
      setState(() {
        _permissionsGranted = false;
        _status = 'Location permission denied';
      });
    }
  }

  Future<void> _initProximiio() async {
    setState(() {
      _status = 'Authorizing with Proximiio...';
    });

    try {
      final state = await FlutterProximiio.authorize(token);

      if (state.ready) {
        setState(() {
          _visitorId = state.visitorId;
          _status = 'Connected';
        });

        // Subscribe to floor changes
        FlutterProximiio.subscribe(
          ProximiioEvents.floorChanged,
          (ProximiioFloor floor) {
            setState(() {
              _floor = floor;
            });
          },
        );

        // Subscribe to position updates
        FlutterProximiio.subscribe(
          ProximiioEvents.positionUpdated,
          (ProximiioLocation location) {
            debugPrint('📍 [Data Tab] Received position update: lat=${location.lat}, lng=${location.lng}, source=${location.sourceType}');
            setState(() {
              _location = location;
              debugPrint('📍 [Data Tab] setState called, _location updated');
            });
          },
        );

        // Subscribe to geofence events
        final updateGeofences = (ProximiioGeofence geofence) async {
          final current = await FlutterProximiio.currentGeofences();
          setState(() {
            _geofences = current;
          });
        };

        FlutterProximiio.subscribe(
          ProximiioEvents.enteredGeofence,
          updateGeofences,
        );

        FlutterProximiio.subscribe(
          ProximiioEvents.exitedGeofence,
          updateGeofences,
        );

        // Request permissions and set accuracy
        await FlutterProximiio.requestPermissions();
        await FlutterProximiio.setNativeAccuracy(NativeAccuracy.gps);

        setState(() {
          _status = 'Tracking started';
        });
      } else {
        setState(() {
          _status = 'Authorization failed';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      debugPrint('Error initializing Proximiio: $e');
    }
  }

  Color _getStatusColor() {
    if (_status.contains('Error') || _status.contains('denied') || _status.contains('failed')) {
      return Colors.red;
    } else if (_status.contains('Tracking started') || _status.contains('Connected')) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }

  IconData _getStatusIcon() {
    if (_status.contains('Error') || _status.contains('denied') || _status.contains('failed')) {
      return Icons.error;
    } else if (_status.contains('Tracking started') || _status.contains('Connected')) {
      return Icons.check_circle;
    } else {
      return Icons.info;
    }
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
