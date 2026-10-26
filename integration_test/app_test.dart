import 'package:flutter/material.dart';
import 'package:flutter_proximiio_map/flutter_proximiio_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:proximiio_flutter_example/main.dart';
import 'package:webview_flutter/webview_flutter.dart';

// Runs against the live API with the token of env.json:
//   flutter test integration_test -d <device> --dart-define-from-file=env.json
// The app asks for location when it starts; allow it within 60 s. `flutter test` reinstalls the app,
// which drops an earlier grant. See the README for granting it on the iOS Simulator.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts positioning, opens the map and the web app, and stops', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await _pumpUntil(tester, () => _shown('SDK running') || _error() != null);
    expect(_error(), isNull);

    await tester.tap(find.text('Map'));
    await _pumpUntil(tester, () => _shown('Recentre'));
    expect(find.byType(ProximiioMap), findsOneWidget);

    await tester.tap(find.text('Web'));
    await _pumpUntil(tester, () => find.byType(WebViewWidget).evaluate().isNotEmpty || _shown(_noWayfindingUrl));

    await tester.tap(find.text('Position'));
    await _pumpUntil(tester, () => _shown('Stop'));
    await tester.tap(find.text('Stop'));
    await _pumpUntil(tester, () => _shown('SDK authenticated'));
    expect(_error(), isNull);
  });
}

const _noWayfindingUrl = 'No wayfinding URL. Set PROXIMIIO_WAYFINDING_URL in env.json.';

bool _shown(String text) => find.text(text).evaluate().isNotEmpty;

/// The error the state card shows, if any.
String? _error() => switch (find.byKey(const ValueKey('sdk-error')).evaluate().firstOrNull?.widget) {
  final Text text => text.data,
  _ => null,
};

Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (!done()) {
    if (DateTime.now().isAfter(end)) {
      final shown = find.byType(Text).evaluate().map((element) => (element.widget as Text).data).nonNulls;
      fail('Timed out. Shown: ${shown.join(' | ')}');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
