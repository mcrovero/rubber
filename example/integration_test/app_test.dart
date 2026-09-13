import 'package:example/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens and expands the default bottom sheet', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    await tester.tap(find.text('Default'));
    await tester.pumpAndSettle();

    final sheet = find.byType(FractionallySizedBox);
    expect(sheet, findsOneWidget);
    final collapsedHeight = tester.getSize(sheet).height;

    await tester.tap(find.byIcon(Icons.vertical_align_top));
    await tester.pumpAndSettle();

    expect(tester.getSize(sheet).height, greaterThan(collapsedHeight));
    expect(tester.takeException(), isNull);
  });
}
