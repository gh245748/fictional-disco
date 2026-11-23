import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('Meşk')));
    expect(find.text('Meşk'), findsOneWidget);
  });
}
