import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firewood/app.dart';

void main() {
  testWidgets('FirewoodApp launches correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FirewoodApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(FirewoodApp), findsOneWidget);
  });
}
