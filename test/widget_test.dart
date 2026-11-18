import 'package:flutter_test/flutter_test.dart';
import 'package:nyayvaani/main.dart';

void main() {
  testWidgets('App loads splash branding', (WidgetTester tester) async {
    await tester.pumpWidget(const NyayaVaaniApp());
    expect(find.text('NyayVanni'), findsWidgets);
  });
}
