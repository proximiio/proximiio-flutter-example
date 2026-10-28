import 'package:flutter/material.dart';
import 'package:flutter_proximiio/flutter_proximiio.dart';

import 'session.dart';

/// What the SDK reports: its state, the visitor, permissions, position, floor, geofences and events.
class StatusTab extends StatelessWidget {
  const StatusTab({super.key, required this.session});

  final SdkSession session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final position = session.position;
      final permissions = session.permissions;
      final geofences = session.geofencesInside.values;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StateCard(session: session),
          InfoCard('Visitor', [
            ('Application', session.application?.name ?? session.application?.id ?? '-'),
            (
              'Visitor ID',
              switch (session.visitorId) {
                final id? when id.isNotEmpty => id,
                _ => '-',
              },
            ),
          ]),
          InfoCard('Position', [
            if (position == null)
              ('Position', 'None yet')
            else ...[
              ('Latitude', position.coordinate.latitude.toStringAsFixed(7)),
              ('Longitude', position.coordinate.longitude.toStringAsFixed(7)),
              ('Accuracy', '±${position.horizontalAccuracy.toStringAsFixed(1)} m'),
              ('Source', position.source.name),
              ('Updated', clock(position.timestamp)),
            ],
            (
              'Heading',
              switch (session.heading) {
                final heading? => '${heading.round()}° (from PDR steps)',
                null => 'No steps yet',
              },
            ),
            (
              'Floor',
              session.reportedFloor == null
                  ? '${session.currentFloor?.name ?? 'level ${defaultLevel.round()}'} (default)'
                  : floorName(session.reportedFloor),
            ),
          ]),
          InfoCard('Permissions', [
            if (permissions == null)
              ('Status', 'Not asked yet')
            else ...[
              ('Location', permissions.location.name),
              ('Accuracy', permissions.accuracy.name),
              ('Bluetooth', permissions.bluetooth.name),
              ('Motion', permissions.motion.name),
            ],
          ]),
          InfoCard('Geofences', [
            (
              'Inside',
              geofences.isEmpty ? 'None' : geofences.map((geofence) => geofence.name ?? geofence.id).join(', '),
            ),
          ]),
          InfoCard('Events', [
            if (session.events.isEmpty) ('', 'None yet') else for (final line in session.events) ('', line),
          ]),
        ],
      );
    },
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.session});

  final SdkSession session;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final error = session.error;
    final running = session.state == ProximiioState.running;
    final changing =
        session.busy || session.state == ProximiioState.starting || session.state == ProximiioState.stopping;
    return Card(
      color: error != null
          ? colors.errorContainer
          : running
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('SDK ${session.state.name}', style: Theme.of(context).textTheme.titleMedium)),
                if (changing)
                  const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else if (running)
                  OutlinedButton(onPressed: session.stop, child: const Text('Stop'))
                else
                  FilledButton(onPressed: session.connect, child: const Text('Start')),
              ],
            ),
            if (error != null) ...[const SizedBox(height: 8), Text(error, key: const ValueKey('sdk-error'))],
          ],
        ),
      ),
    );
  }
}

/// A titled card of label and value rows. A row with an empty label gives the value the whole width.
class InfoCard extends StatelessWidget {
  const InfoCard(this.title, this.rows, {super.key});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label.isNotEmpty)
                    SizedBox(
                      width: 100,
                      child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                  Expanded(child: Text(value)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
