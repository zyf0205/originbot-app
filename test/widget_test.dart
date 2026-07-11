import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    await tester.pumpWidget(const OriginBotApp());
    await tester.pumpAndSettle();
    expect(find.text('OriginBot'), findsWidgets);
  });
}
