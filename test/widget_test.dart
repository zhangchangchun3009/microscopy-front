import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/app_config.dart';
import 'package:microscope_app/main.dart';

void main() {
  testWidgets('HomePage renders with title and chat header',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          initialConfig: AppConfig(),
          skipAutoConnect: true,
        ),
      ),
    );

    expect(find.text('显微镜代理'), findsOneWidget);
    expect(find.text('Agent 对话'), findsOneWidget);
  });

  testWidgets('视频暂停后隐藏，再次点击恢复重新显示流',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          initialConfig: AppConfig(),
          skipAutoConnect: true,
        ),
      ),
    );

    // 初始应显示视频流组件
    expect(find.byType(Mjpeg), findsOneWidget);

    // 点击暂停按钮后，视频流组件应被移除
    await tester.tap(find.byTooltip('暂停'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Mjpeg), findsNothing);

    // 再次点击恢复按钮，应重新创建视频流组件
    await tester.tap(find.byTooltip('继续'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Mjpeg), findsOneWidget);
  });
}
