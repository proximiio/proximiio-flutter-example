import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';
import 'package:share_plus/share_plus.dart';

import 'session.dart';
import 'status_tab.dart';

/// What the SDK sees, for field tests: its diagnostics, the beacons in range, and the SDK's report to share.
///
/// It refreshes every second while [active].
class DiagnosticsTab extends StatefulWidget {
  const DiagnosticsTab({super.key, required this.session, required this.active});

  final SdkSession session;
  final bool active;

  @override
  State<DiagnosticsTab> createState() => _DiagnosticsTabState();
}

class _DiagnosticsTabState extends State<DiagnosticsTab> {
  ProximiioDiagnostics? _diagnostics;
  String? _error;
  Timer? _timer;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _poll();
  }

  @override
  void didUpdateWidget(DiagnosticsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _poll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _poll() {
    _timer?.cancel();
    _timer = null;
    if (!widget.active) return;
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_refresh()));
  }

  Future<void> _refresh() async {
    final sdk = widget.session.sdk;
    if (sdk == null) return;
    try {
      final diagnostics = await sdk.diagnostics();
      if (!mounted) return;
      setState(() {
        _diagnostics = diagnostics;
        _error = null;
      });
    } on ProximiioException catch (error) {
      if (mounted) setState(() => _error = error.code.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = _diagnostics;
    final position = widget.session.position;
    final beacons = _beacons();
    final now = DateTime.now();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InfoCard('Diagnostics', [
          if (diagnostics == null)
            ('Status', _error ?? 'Waiting for the SDK')
          else ...[
            ('SDK', diagnostics.state.name),
            ('Source', diagnostics.lastPositionSource?.name ?? '-'),
            ('Accuracy', position == null ? '-' : '±${position.horizontalAccuracy.toStringAsFixed(1)} m'),
            ('Position age', _seconds(diagnostics.lastPositionAge)),
            ('No position', diagnostics.noPositionReason ?? '-'),
            (
              'Beacons',
              '${diagnostics.visibleBeaconCount} in range, ${diagnostics.registeredBeaconCount} in the venue',
            ),
            (
              'PDR',
              diagnostics.pdrRunning
                  ? 'running'
                  : diagnostics.pdrEnabled
                  ? 'on, not running'
                  : 'off',
            ),
            ('Heading', widget.session.heading == null ? 'No steps yet' : '${widget.session.heading!.round()}°'),
            ('Taken', clock(diagnostics.generatedAt)),
          ],
          if (_error case final error? when diagnostics != null) ('Error', error),
        ]),
        InfoCard('Beacons in range (${beacons.length})', [
          if (beacons.isEmpty)
            ('', 'None')
          else
            for (final beacon in beacons) ('${beacon.rssi} dBm', _describe(beacon, now, short: true)),
        ]),
        if (diagnostics != null) InfoCard('Summary', [('', diagnostics.summary)]),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: diagnostics == null ? null : _copy,
                icon: const Icon(Icons.copy),
                label: const Text('Copy'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: widget.session.sdk == null || _sharing ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: const Text('Share report'),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Copy puts the diagnostics and the beacons on the clipboard. Share report sends the SDK recording '
            'since the app started, as a zip without the token.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  /// The beacons in range, strongest first.
  List<BeaconObservation> _beacons() =>
      widget.session.beacons.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));

  Future<void> _copy() async {
    final diagnostics = _diagnostics;
    if (diagnostics == null) return;
    final position = widget.session.position;
    final now = DateTime.now();
    final beacons = _beacons();
    final text = [
      diagnostics.summary,
      if (position != null)
        'Position ${position.coordinate.latitude.toStringAsFixed(7)}, '
            '${position.coordinate.longitude.toStringAsFixed(7)} '
            '±${position.horizontalAccuracy.toStringAsFixed(1)} m, ${position.source.name}, ${clock(position.timestamp)}',
      'Beacons in range (${beacons.length}):',
      for (final beacon in beacons) '${beacon.rssi} dBm  ${_describe(beacon, now)}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    _tell('Copied');
  }

  Future<void> _share() async {
    final sdk = widget.session.sdk;
    if (sdk == null) return;
    setState(() => _sharing = true);
    try {
      final path = await sdk.prepareDiagnosticsReport();
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], subject: 'Proximi.io diagnostics'));
    } on ProximiioException catch (error) {
      _tell('No report: ${error.code.name}');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _tell(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The beacon, its transmit power and distance when known, and how long ago it was seen. [short] gives an
/// iBeacon by the first group of its UUID, which is enough to tell a venue's beacons apart.
String _describe(BeaconObservation beacon, DateTime now, {bool short = false}) {
  final distance = beacon.calibratedDistance;
  return [
    switch (beacon.identifier) {
      IBeaconIdentifier(:final uuid, :final major, :final minor) when short => '${uuid.split('-').first} $major/$minor',
      final identifier => '$identifier',
    },
    if (beacon.txPower case final txPower?) 'tx $txPower dBm',
    if (distance != null) '${distance.toStringAsFixed(1)} m',
    '${_seconds(now.difference(beacon.timestamp))} ago',
  ].join(' · ');
}

String _seconds(Duration? duration) =>
    duration == null ? '-' : '${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s';
