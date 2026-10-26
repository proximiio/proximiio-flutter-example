import 'package:flutter_test/flutter_test.dart';
import 'package:proximiio_flutter_example/main.dart';

void main() {
  testWidgets('asks for a token when the build has none', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.textContaining('No token.'), findsOneWidget);
  });
}
