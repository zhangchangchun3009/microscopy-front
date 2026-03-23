import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/layout/right_chat_split_layout.dart';

void main() {
  group('RightChatSplitLayout', () {
    testWidgets('shows collapse button centered on left border when expanded',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RightChatSplitLayout(
              leftPane: Container(color: Colors.blue),
              rightChatPane: Container(color: Colors.green),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Verify button is positioned on the left edge
      final button = tester.widget<Positioned>(
        find.ancestor(
          of: find.byIcon(Icons.chevron_right),
          matching: find.byType(Positioned),
        ),
      );
      expect(button.left, equals(-8));
    });

    testWidgets('collapse button toggles chat panel', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RightChatSplitLayout(
              leftPane: Container(color: Colors.blue),
              rightChatPane: Container(color: Colors.green),
            ),
          ),
        ),
      );

      // Act: Click collapse button
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      // Assert: Should show collapsed handle with left chevron
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });
  });
}
