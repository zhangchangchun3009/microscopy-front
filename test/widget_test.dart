import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/app_config.dart';
import 'package:microscope_app/main.dart';

Future<void> _pumpStableFrame(WidgetTester tester) async {
  // 用有限帧推进替代 pumpAndSettle，避免在持续动画场景下卡住。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

void main() {
  testWidgets('HomePage 渲染核心布局', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(initialConfig: AppConfig(), skipAutoConnect: true),
      ),
    );
    await _pumpStableFrame(tester);

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byKey(const ValueKey('video-stage')), findsOneWidget);
    expect(find.byKey(const ValueKey('right-chat-panel')), findsOneWidget);
  });

  testWidgets('视频暂停后隐藏，再次点击恢复重新显示流', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(initialConfig: AppConfig(), skipAutoConnect: true),
      ),
    );

    // 初始应显示视频流组件
    expect(find.byType(Mjpeg), findsOneWidget);

    // 点击暂停按钮后，视频流组件应被移除（通过 icon 查找，避免 tooltip 文案绑定）
    await tester.tap(find.byIcon(Icons.pause));
    await _pumpStableFrame(tester);
    expect(find.byType(Mjpeg), findsNothing);

    // 再次点击恢复按钮，应重新创建视频流组件
    await tester.tap(find.byIcon(Icons.play_arrow));
    await _pumpStableFrame(tester);
    expect(find.byType(Mjpeg), findsOneWidget);
  });

  testWidgets('聊天面板位于右侧且默认宽度受最小宽度约束', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(initialConfig: AppConfig(), skipAutoConnect: true),
      ),
    );
    await _pumpStableFrame(tester);

    final chatPanelFinder = find.byKey(const ValueKey('right-chat-panel'));
    final videoStageFinder = find.byKey(const ValueKey('video-stage'));
    expect(chatPanelFinder, findsOneWidget);
    expect(videoStageFinder, findsOneWidget);

    final chatRect = tester.getRect(chatPanelFinder);
    final videoRect = tester.getRect(videoStageFinder);
    expect(chatRect.left, greaterThan(videoRect.left));
    // 默认 30% 为 300px，但受 effectiveMinWidth=min(320,maxWidth) 约束后应为 320px。
    expect(chatRect.width, closeTo(320, 2));
  });

  testWidgets('折叠后聊天内容不可见，仅保留24px把手', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(initialConfig: AppConfig(), skipAutoConnect: true),
      ),
    );
    await _pumpStableFrame(tester);

    expect(find.byKey(const ValueKey('right-chat-panel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('right-chat-toggle-handle')));
    await _pumpStableFrame(tester);

    expect(find.byKey(const ValueKey('right-chat-panel')), findsNothing);
    final handleRect = tester.getRect(
      find.byKey(const ValueKey('right-chat-collapsed-handle')),
    );
    expect(handleRect.width, 24);
  });

  testWidgets('左拖边界可增宽，右拖可变窄', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(initialConfig: AppConfig(), skipAutoConnect: true),
      ),
    );
    await _pumpStableFrame(tester);

    final panelFinder = find.byKey(const ValueKey('right-chat-panel'));
    final dragHandleFinder = find.byKey(
      const ValueKey('right-chat-drag-handle'),
    );
    expect(panelFinder, findsOneWidget);
    expect(dragHandleFinder, findsOneWidget);

    final widthBefore = tester.getRect(panelFinder).width;
    await tester.drag(dragHandleFinder, const Offset(-100, 0));
    await _pumpStableFrame(tester);
    final widthAfterLeftDrag = tester.getRect(panelFinder).width;
    expect(widthAfterLeftDrag, greaterThan(widthBefore));

    await tester.drag(dragHandleFinder, const Offset(80, 0));
    await _pumpStableFrame(tester);
    final widthAfterRightDrag = tester.getRect(panelFinder).width;
    expect(widthAfterRightDrag, lessThan(widthAfterLeftDrag));
  });

  testWidgets('聊天宽度上限不超过窗口50%', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(initialConfig: AppConfig(), skipAutoConnect: true),
      ),
    );
    await _pumpStableFrame(tester);

    final panelFinder = find.byKey(const ValueKey('right-chat-panel'));
    final dragHandleFinder = find.byKey(
      const ValueKey('right-chat-drag-handle'),
    );

    await tester.drag(dragHandleFinder, const Offset(-1000, 0));
    await _pumpStableFrame(tester);

    final width = tester.getRect(panelFinder).width;
    expect(width, lessThanOrEqualTo(500));
  });

  testWidgets('折叠状态下拖拽无效', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(initialConfig: AppConfig(), skipAutoConnect: true),
      ),
    );
    await _pumpStableFrame(tester);

    await tester.tap(find.byKey(const ValueKey('right-chat-toggle-handle')));
    await _pumpStableFrame(tester);

    final collapsedFinder = find.byKey(
      const ValueKey('right-chat-collapsed-handle'),
    );
    expect(collapsedFinder, findsOneWidget);
    final widthBefore = tester.getRect(collapsedFinder).width;

    await tester.drag(collapsedFinder, const Offset(-120, 0));
    await _pumpStableFrame(tester);
    final widthAfter = tester.getRect(collapsedFinder).width;

    expect(widthAfter, widthBefore);
  });

  testWidgets('折叠/展开后聊天消息与输入状态保持连续', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(initialConfig: AppConfig(), skipAutoConnect: true),
      ),
    );
    await _pumpStableFrame(tester);

    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpStableFrame(tester);
    // 状态行只在 _messages 中；ChatPanel 仅渲染 turns，故无「正在连接」可见文案。

    final chatInputFinder = find.byKey(const ValueKey('chat-input-field'));
    expect(chatInputFinder, findsOneWidget);
    // 无 turn 时列表区为占位文案，而非带 key 的 ListView
    expect(find.text('发送消息开始对话'), findsOneWidget);
    await tester.enterText(chatInputFinder, '草稿输入应保留');
    await _pumpStableFrame(tester);

    await tester.tap(find.byKey(const ValueKey('right-chat-toggle-handle')));
    await _pumpStableFrame(tester);
    expect(find.byKey(const ValueKey('right-chat-panel')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('right-chat-toggle-handle')));
    await _pumpStableFrame(tester);

    expect(find.byKey(const ValueKey('right-chat-panel')), findsOneWidget);
    expect(find.text('发送消息开始对话'), findsOneWidget);
    expect(find.text('草稿输入应保留'), findsOneWidget);
  });

  testWidgets('折叠/展开幂等：重复切换不破坏聊天状态', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(initialConfig: AppConfig(), skipAutoConnect: true),
      ),
    );
    await _pumpStableFrame(tester);

    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpStableFrame(tester);

    final chatInputFinder = find.byKey(const ValueKey('chat-input-field'));
    expect(chatInputFinder, findsOneWidget);
    await tester.enterText(chatInputFinder, '重复切换后仍应保留');
    await _pumpStableFrame(tester);

    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const ValueKey('right-chat-toggle-handle')));
      await _pumpStableFrame(tester);
    }

    expect(find.byKey(const ValueKey('right-chat-panel')), findsOneWidget);
    expect(find.text('重复切换后仍应保留'), findsOneWidget);
    expect(find.text('发送消息开始对话'), findsOneWidget);
  });
}
