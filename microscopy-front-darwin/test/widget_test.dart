import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/main.dart';

void main() {
  testWidgets('App renders with title', (WidgetTester tester) async {
    await tester.pumpWidget(const MicroscopeApp());
    expect(find.text('显微镜代理'), findsOneWidget);
    expect(find.text('Agent 对话'), findsOneWidget);
  });
}
