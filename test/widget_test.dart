import 'package:flutter_test/flutter_test.dart';
import 'package:stylestore_mobile/main.dart';

void main() {
  testWidgets('StyleStoreApp smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const StyleStoreApp());

    // Verify that the title or app is rendered
    expect(find.byType(StyleStoreApp), findsOneWidget);
  });
}
