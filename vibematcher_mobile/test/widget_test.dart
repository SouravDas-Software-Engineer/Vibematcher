import 'package:flutter_test/flutter_test.dart';
import 'package:vibematcher/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VibeMatcherApp());
    expect(find.byType(VibeMatcherApp), findsOneWidget);
  });
}
