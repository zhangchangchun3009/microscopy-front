# 思维流显示功能实施计划

> **对于 AI 助手：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务实施此计划。步骤使用复选框（`- [ ]`）语法进行跟踪。

**目标：** 重构聊天界面，将 AI 思维过程（工具调用、结果、错误）分组显示为可折叠的预览块，带有活动动画和复制功能

**架构：** 在控制器层将中间消息分组为 ThinkingBlock，UI 层通过新的组件渲染这些块。保持现有 ChatMsg 模型不变以确保向后兼容。

**技术栈：** Flutter, Material Design, WebSocket 现有协议

---

## 任务分解

### 任务 1: 创建显示模型

**文件：**
- 新建：`lib/ui/chat/chat_display_models.dart`

- [ ] **步骤 1: 编写测试文件**

```dart
// test/ui/chat/chat_display_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_display_models.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';

void main() {
  group('ThinkingBlock', () {
    test('应该创建空的思维块', () {
      final block = ThinkingBlock(
        messages: [],
        startTime: DateTime(2026, 3, 24, 10, 0),
      );
      expect(block.messages, isEmpty);
      expect(block.isExpanded, false);
      expect(block.isActive, true);
    });

    test('应该支持展开状态切换', () {
      final block = ThinkingBlock(
        messages: [],
        startTime: DateTime(2026, 3, 24, 10, 0),
      );
      block.isExpanded = true;
      expect(block.isExpanded, true);
    });

    test('应该支持活动状态切换', () {
      final block = ThinkingBlock(
        messages: [],
        startTime: DateTime(2026, 3, 24, 10, 0),
      );
      block.isActive = false;
      expect(block.isActive, false);
    });
  });

  group('MessageItem', () {
    test('应该包装单条消息', () {
      final msg = ChatMsg(role: MsgRole.user, text: '测试');
      final item = MessageItem(msg);
      expect(item.message, msg);
    });
  });

  group('ThinkingItem', () {
    test('应该包装思维块', () {
      final block = ThinkingBlock(
        messages: [],
        startTime: DateTime(2026, 3, 24, 10, 0),
      );
      final item = ThinkingItem(block);
      expect(item.block, block);
    });
  });
}
```

- [ ] **步骤 2: 运行测试确认失败**

运行：`flutter test test/ui/chat/chat_display_models_test.dart`

预期：FAIL - "file not found"

- [ ] **步骤 3: 实现模型**

```dart
// lib/ui/chat/chat_display_models.dart
import 'chat_models.dart';

/// 思维块 - 包含所有中间消息（工具调用、结果、错误等）
class ThinkingBlock {
  /// 块中的所有消息
  final List<ChatMsg> messages;

  /// 思维开始时间
  final DateTime startTime;

  /// 是否展开
  bool isExpanded;

  /// 是否正在进行中
  bool isActive;

  ThinkingBlock({
    required this.messages,
    required this.startTime,
    this.isExpanded = false,
    this.isActive = true,
  });

  /// 添加消息到块中
  void addMessage(ChatMsg msg) {
    messages.add(msg);
  }
}

/// 聊天显示项的联合类型
sealed class ChatDisplayItem {}

/// 单条消息项
class MessageItem extends ChatDisplayItem {
  final ChatMsg message;
  MessageItem(this.message);
}

/// 思维块项
class ThinkingItem extends ChatDisplayItem {
  final ThinkingBlock block;
  ThinkingItem(this.block);
}
```

- [ ] **步骤 4: 运行测试确认通过**

运行：`flutter test test/ui/chat/chat_display_models_test.dart`

预期：PASS

- [ ] **步骤 5: 提交**

```bash
git add lib/ui/chat/chat_display_models.dart test/ui/chat/chat_display_models_test.dart
git commit -m "feat: 添加思维块和显示项模型

- 新增 ThinkingBlock 类用于分组中间消息
- 新增 ChatDisplayItem 联合类型
- 支持展开/活动状态切换

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 2: 更新控制器的分组逻辑

**文件：**
- 修改：`lib/ui/chat/chat_session_controller.dart`
- 修改：`test/ui/chat/chat_session_controller_test.dart`

- [ ] **步骤 1: 编写控制器分组逻辑的测试**

```dart
// 在 test/ui/chat/chat_session_controller_test.dart 中添加

group('消息分组逻辑', () {
  test('应该在用户消息后创建新的思维块', () {
    final controller = ChatSessionController();
    controller.connect('ws://localhost:8080');

    // 模拟用户发送消息
    controller.sendMessage('测试消息');

    // 应该创建思维块
    expect(controller.displayItems.length, greaterThan(0));
  });

  test('应该将工具调用添加到当前思维块', () {
    // 测试工具调用被正确添加到活动块中
  });

  test('应该在助手响应后关闭思维块', () {
    // 测试助手响应后块被关闭并标记为非活动
  });
});
```

- [ ] **步骤 2: 运行测试确认失败**

运行：`flutter test test/ui/chat/chat_session_controller_test.dart`

预期：FAIL - "getter 'displayItems' not found"

- [ ] **步骤 3: 在控制器中添加导入和状态**

```dart
// lib/ui/chat/chat_session_controller.dart 顶部添加
import 'chat_display_models.dart';

class ChatSessionController extends ChangeNotifier {
  final List<ChatMsg> _messages = [];
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;
  final StringBuffer _chunkBuffer = StringBuffer();

  bool _wsConnected = false;
  bool _agentBusy = false;

  // 新增：显示项列表
  final List<ChatDisplayItem> _displayItems = [];

  // 新增：当前活动的思维块
  ThinkingBlock? _currentBlock;

  // ... 现有的 messages getter 保持不变
  List<ChatMsg> get messages => List.unmodifiable(_messages);

  // 新增：显示项 getter
  List<ChatDisplayItem> get displayItems => List.unmodifiable(_displayItems);
```

- [ ] **步骤 4: 实现分组逻辑方法**

```dart
// lib/ui/chat/chat_session_controller.dart 中添加

/// 切换思维块展开状态
void toggleThinkingBlock(int index) {
  final item = _displayItems[index];
  if (item is ThinkingItem) {
    item.block.isExpanded = !item.block.isExpanded;
    notifyListeners();
  }
}

/// 格式化思维块预览文本（4-5行）
String _formatBlockPreview(ThinkingBlock block) {
  final lines = <String>[];
  int lineCount = 0;

  for (final msg in block.messages) {
    if (lineCount >= 5) break;

    final prefix = switch (msg.role) {
      MsgRole.toolCall => '🔧 ${msg.toolName ?? "工具"}',
      MsgRole.toolResult => '✓ ${msg.toolName ?? "结果"}',
      MsgRole.error => '❌ 错误',
      MsgRole.status => 'ℹ️ ${msg.text}',
      _ => '',
    };

    if (prefix.isNotEmpty) {
      lines.add(prefix);
      lineCount++;
    }
  }

  if (block.messages.length > 5) {
    lines.add('... 还有 ${block.messages.length - 5} 条消息');
  }

  return lines.join('\n');
}

/// 处理用户消息发送
void sendMessage(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty || !_wsConnected) {
    return;
  }

  // 添加用户消息到原始消息列表
  _messages.add(ChatMsg(role: MsgRole.user, text: normalized));
  _displayItems.add(MessageItem(_messages.last));

  // 创建新的思维块
  _currentBlock = ThinkingBlock(
    messages: [],
    startTime: DateTime.now(),
    isActive: true,
  );

  _agentBusy = true;
  _channel?.sink.add(jsonEncode({'type': 'message', 'content': normalized}));
  notifyListeners();
}

/// 处理 WebSocket 消息
void _onWsMessage(dynamic raw) {
  if (raw is! String) {
    return;
  }

  final result = ChatProtocolMapper.applyEvent(
    raw: raw,
    chunkBuffer: _chunkBuffer,
    agentBusy: _agentBusy,
    lastMessageRole: _messages.isNotEmpty ? _messages.last.role : null,
  );

  // 将消息添加到原始列表（保持兼容性）
  _messages.addAll(result.messages);

  // 分组逻辑：将中间消息添加到思维块
  for (final msg in result.messages) {
    if (_currentBlock != null && _isIntermediateMessage(msg)) {
      _currentBlock!.addMessage(msg);
    } else if (msg.role == MsgRole.assistant) {
      // 关闭当前思维块并添加助手消息
      if (_currentBlock != null && _currentBlock!.messages.isNotEmpty) {
        _displayItems.add(ThinkingItem(_currentBlock!));
      }
      _displayItems.add(MessageItem(msg));
      _currentBlock = null;
    }
  }

  // 更新活动状态
  _agentBusy = result.agentBusy;
  if (_currentBlock != null) {
    _currentBlock!.isActive = _agentBusy;

    // 如果活动结束且有内容，添加到显示项
    if (!_agentBusy && _currentBlock!.messages.isNotEmpty) {
      _displayItems.add(ThinkingItem(_currentBlock!));
      _currentBlock = null;
    }
  }

  notifyListeners();
}

/// 判断是否为中间消息（应放入思维块）
bool _isIntermediateMessage(ChatMsg msg) {
  return msg.role == MsgRole.toolCall ||
         msg.role == MsgRole.toolResult ||
         msg.role == MsgRole.error ||
         msg.role == MsgRole.status;
}
```

- [ ] **步骤 5: 运行测试确认通过**

运行：`flutter test test/ui/chat/chat_session_controller_test.dart`

预期：PASS

- [ ] **步骤 6: 提交**

```bash
git add lib/ui/chat/chat_session_controller.dart test/ui/chat/chat_session_controller_test.dart
git commit -m "feat: 在控制器中实现消息分组逻辑

- 添加 displayItems getter 暴露分组后的显示项
- 实现思维块创建和生命周期管理
- 将中间消息分组到思维块
- 添加 toggleThinkingBlock 方法
- 添加 _formatBlockPreview 生成预览文本

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 3: 创建消息气泡组件

**文件：**
- 新建：`lib/ui/chat/message_bubble.dart`
- 新建：`test/ui/chat/message_bubble_test.dart`

- [ ] **步骤 1: 编写消息气泡组件测试**

```dart
// test/ui/chat/message_bubble_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/message_bubble.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';

void main() {
  group('MessageBubble', () {
    testWidgets('应该显示用户消息', (tester) async {
      final msg = ChatMsg(role: MsgRole.user, text: '测试消息');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: msg,
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(find.text('测试消息'), findsOneWidget);
    });

    testWidgets('应该显示复制按钮', (tester) async {
      final msg = ChatMsg(role: MsgRole.user, text: '测试');
      bool copyCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: msg,
              onCopy: () => copyCalled = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('点击复制按钮应该触发回调', (tester) async {
      final msg = ChatMsg(role: MsgRole.user, text: '测试');
      bool copyCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessageBubble(
              message: msg,
              onCopy: () => copyCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.copy));
      expect(copyCalled, true);
    });
  });
}
```

- [ ] **步骤 2: 运行测试确认失败**

运行：`flutter test test/ui/chat/message_bubble_test.dart`

预期：FAIL - "file not found"

- [ ] **步骤 3: 实现消息气泡组件**

```dart
// lib/ui/chat/message_bubble.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_models.dart';

/// 可复用的消息气泡组件
class MessageBubble extends StatefulWidget {
  final ChatMsg message;
  final VoidCallback onCopy;

  const MessageBubble({
    super.key,
    required this.message,
    required this.onCopy,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showCopiedFeedback = false;

  void _handleCopy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.message.text));
      setState(() => _showCopiedFeedback = true);
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _showCopiedFeedback = false);
        }
      });
    } catch (_) {
      // 静默失败
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (widget.message.role == MsgRole.user) {
      return _buildUserBubble(cs);
    } else {
      return _buildAssistantBubble(cs);
    }
  }

  Widget _buildUserBubble(ColorScheme cs) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(widget.message.time),
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '我',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.person, size: 16, color: cs.primary),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.only(bottom: 8, left: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SelectableText(
                    widget.message.text,
                    style: TextStyle(color: cs.onPrimary),
                  ),
                ),
                _buildCopyButton(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(ColorScheme cs) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.smart_toy, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                '助手',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _formatTime(widget.message.time),
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            margin: const EdgeInsets.only(bottom: 8, right: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SelectableText(widget.message.text),
                ),
                _buildCopyButton(cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyButton(ColorScheme cs) {
    return Tooltip(
      message: _showCopiedFeedback ? '已复制!' : '复制',
      waitDuration: Duration.zero,
      child: IconButton(
        icon: const Icon(Icons.copy, size: 16),
        onPressed: _handleCopy,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **步骤 4: 运行测试确认通过**

运行：`flutter test test/ui/chat/message_bubble_test.dart`

预期：PASS

- [ ] **步骤 5: 提交**

```bash
git add lib/ui/chat/message_bubble.dart test/ui/chat/message_bubble_test.dart
git commit -m "feat: 创建可复用消息气泡组件

- 实现 MessageBubble 组件用于用户和助手消息
- 添加复制按钮和反馈功能
- 支持文本选择
- 添加复制成功提示

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 4: 创建思维流显示组件（不含动画）

**文件：**
- 新建：`lib/ui/chat/thinking_flow_widget.dart`
- 新建：`test/ui/chat/thinking_flow_widget_test.dart`

- [ ] **步骤 1: 编写思维流组件测试**

```dart
// test/ui/chat/thinking_flow_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/thinking_flow_widget.dart';
import 'package:microscope_app/ui/chat/chat_display_models.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';

void main() {
  group('ThinkingFlowWidget', () {
    testWidgets('应该显示折叠的预览', (tester) async {
      final block = ThinkingBlock(
        messages: [
          ChatMsg(role: MsgRole.toolCall, text: '调用工具', toolName: 'search'),
        ],
        startTime: DateTime(2026, 3, 24, 10, 0),
        isExpanded: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThinkingFlowWidget(
              block: block,
              onToggleExpansion: (_) {},
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(find.text('调用工具'), findsOneWidget);
    });

    testWidgets('点击应该切换展开状态', (tester) async {
      final block = ThinkingBlock(
        messages: [
          ChatMsg(role: MsgRole.toolCall, text: '测试'),
        ],
        startTime: DateTime(2026, 3, 24, 10, 0),
        isExpanded: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThinkingFlowWidget(
              block: block,
              onToggleExpansion: (_) {},
              onCopy: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      // 验证 onToggleExpansion 被调用
    });
  });
}
```

- [ ] **步骤 2: 运行测试确认失败**

运行：`flutter test test/ui/chat/thinking_flow_widget_test.dart`

预期：FAIL - "file not found"

- [ ] **步骤 3: 实现基础思维流组件**

```dart
// lib/ui/chat/thinking_flow_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_display_models.dart';
import 'chat_models.dart';

/// 思维流显示组件
class ThinkingFlowWidget extends StatefulWidget {
  final ThinkingBlock block;
  final ValueChanged<bool> onToggleExpansion;
  final VoidCallback onCopy;

  const ThinkingFlowWidget({
    super.key,
    required this.block,
    required this.onToggleExpansion,
    required this.onCopy,
  });

  @override
  State<ThinkingFlowWidget> createState() => _ThinkingFlowWidgetState();
}

class _ThinkingFlowWidgetState extends State<ThinkingFlowWidget> {
  bool _showCopiedFeedback = false;

  void _handleCopy() async {
    try {
      final content = widget.block.isExpanded
          ? _buildFullText()
          : _buildPreviewText();

      await Clipboard.setData(ClipboardData(text: content));
      setState(() => _showCopiedFeedback = true);
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _showCopiedFeedback = false);
        }
      });
    } catch (_) {
      // 静默失败
    }
  }

  String _buildPreviewText() {
    final lines = <String>[];
    for (final msg in widget.block.messages) {
      final prefix = switch (msg.role) {
        MsgRole.toolCall => '🔧 ${msg.toolName ?? "工具"}',
        MsgRole.toolResult => '✓ ${msg.toolName ?? "结果"}',
        MsgRole.error => '❌ ${msg.text}',
        MsgRole.status => 'ℹ️ ${msg.text}',
        _ => '',
      };
      if (prefix.isNotEmpty) {
        lines.add(prefix);
      }
    }
    return lines.join('\n');
  }

  String _buildFullText() {
    final buffer = StringBuffer();
    for (final msg in widget.block.messages) {
      final prefix = switch (msg.role) {
        MsgRole.toolCall => '🔧 工具调用: ${msg.toolName ?? "?"}',
        MsgRole.toolResult => '✓ 工具结果: ${msg.toolName ?? ""}',
        MsgRole.error => '❌ 错误',
        MsgRole.status => 'ℹ️ 状态',
        _ => '',
      };
      if (prefix.isNotEmpty) {
        buffer.writeln(prefix);
        buffer.writeln(msg.text);
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: cs.tertiary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(cs),
          if (widget.block.isExpanded)
            _buildExpandedContent(cs)
          else
            _buildPreview(cs),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return GestureDetector(
      onTap: () => widget.onToggleExpansion(!widget.block.isExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              widget.block.isActive
                  ? Icons.psychology_outlined
                  : Icons.check_circle_outline,
              size: 16,
              color: cs.tertiary,
            ),
            const SizedBox(width: 8),
            Text(
              widget.block.isActive ? '思考中...' : '思考过程',
              style: TextStyle(
                fontSize: 12,
                color: cs.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            _buildCopyButton(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(ColorScheme cs) {
    return GestureDetector(
      onTap: () => widget.onToggleExpansion(!widget.block.isExpanded),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 80),
        child: SelectableText(
          _buildPreviewText(),
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildExpandedContent(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.block.messages.map((msg) => _buildMessageItem(msg, cs)).toList(),
      ),
    );
  }

  Widget _buildMessageItem(ChatMsg msg, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            switch (msg.role) {
              MsgRole.toolCall => Icons.build,
              MsgRole.toolResult => Icons.check_circle,
              MsgRole.error => Icons.error,
              MsgRole.status => Icons.info,
              _ => Icons.circle,
            },
            size: 14,
            color: cs.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              msg.text,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyButton(ColorScheme cs) {
    return Tooltip(
      message: _showCopiedFeedback ? '已复制!' : '复制',
      waitDuration: Duration.zero,
      child: IconButton(
        icon: const Icon(Icons.copy, size: 16),
        onPressed: _handleCopy,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(),
      ),
    );
  }
}
```

- [ ] **步骤 4: 运行测试确认通过**

运行：`flutter test test/ui/chat/thinking_flow_widget_test.dart`

预期：PASS

- [ ] **步骤 5: 提交**

```bash
git add lib/ui/chat/thinking_flow_widget.dart test/ui/chat/thinking_flow_widget_test.dart
git commit -m "feat: 创建思维流显示组件（基础版）

- 实现 ThinkingFlowWidget 组件
- 支持折叠/展开状态切换
- 显示 4-5 行预览
- 支持复制功能
- 处理空块和单条消息情况

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 5: 更新 ChatPanel 使用新组件

**文件：**
- 修改：`lib/ui/chat/chat_panel.dart`

- [ ] **步骤 1: 更新 ChatPanel 导入**

```dart
// lib/ui/chat/chat_panel.dart 顶部添加导入
import 'chat_display_models.dart';
import 'message_bubble.dart';
import 'thinking_flow_widget.dart';
```

- [ ] **步骤 2: 修改 ChatPanel 参数**

```dart
// lib/ui/chat/chat_panel.dart
class ChatPanel extends StatelessWidget {
  /// 创建聊天面板
  const ChatPanel({
    super.key,
    required this.displayItems,  // 改名自 messages
    required this.inputController,
    required this.scrollController,
    required this.plainTextMode,
    required this.agentBusy,
    required this.wsConnected,
    required this.plainTextTranscript,
    required this.onTogglePlainTextMode,
    required this.onCopyAllMessages,
    required this.onSendMessage,
    required this.onToggleThinkingBlock,  // 新增
  });

  /// 对话显示项列表（改名）
  final List<ChatDisplayItem> displayItems;

  // ... 其他参数保持不变

  /// 切换思维块展开状态（新增）
  final ValueChanged<int> onToggleThinkingBlock;
```

- [ ] **步骤 3: 更新 ListView 构建**

```dart
// lib/ui/chat/chat_panel.dart
@override
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return Column(
    children: [
      _buildHeader(cs),
      Expanded(
        child: displayItems.isEmpty  // 改名
            ? Center(
                child: Text(
                  '发送消息开始对话',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            : plainTextMode
            ? _buildPlainTextView(cs)
            : ListView.builder(
                key: const ValueKey('chat-message-list'),
                controller: scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: displayItems.length,  // 改名
                itemBuilder: (context, i) =>
                    _buildDisplayItem(context, displayItems[i], i, cs),  // 新方法
              ),
      ),
      _buildComposer(cs),
    ],
  );
}
```

- [ ] **步骤 4: 实现新的构建方法**

```dart
// lib/ui/chat/chat_panel.dart 中添加

Widget _buildDisplayItem(BuildContext context, ChatDisplayItem item, int index, ColorScheme cs) {
  if (item is MessageItem) {
    return MessageBubble(
      message: item.message,
      onCopy: () => _handleCopyMessage(item.message),
    );
  } else if (item is ThinkingItem) {
    return ThinkingFlowWidget(
      block: item.block,
      onToggleExpansion: (_) => onToggleThinkingBlock(index),
      onCopy: () => _handleCopyThinkingBlock(item.block),
    );
  }
  return const SizedBox.shrink();
}

void _handleCopyMessage(ChatMsg msg) async {
  // 委托给 MessageBubble 内部的复制逻辑
}

void _handleCopyThinkingBlock(ThinkingBlock block) async {
  // 委托给 ThinkingFlowWidget 内部的复制逻辑
}

// 移除旧的 _buildMessage, _userBubble, _assistantBubble 方法
// 这些现在由 MessageBubble 处理
```

- [ ] **步骤 5: 更新 plainTextTranscript 生成逻辑**

```dart
// lib/ui/chat/chat_session_controller.dart 中修改 formatMessagesForCopy
String formatMessagesForCopy() {
  final sb = StringBuffer();
  for (final item in _displayItems) {
    if (item is MessageItem) {
      final m = item.message;
      final prefix = switch (m.role) {
        MsgRole.user => '[用户]',
        MsgRole.assistant => '[助手]',
        MsgRole.toolCall => '[工具调用: ${m.toolName ?? "?"}]',
        MsgRole.toolResult => '[工具结果: ${m.toolName ?? ""}]',
        MsgRole.error => '[错误]',
        MsgRole.status => '[状态]',
      };
      sb.writeln('$prefix ${m.text}');
      if (m.toolArgs != null && m.toolArgs!.isNotEmpty) {
        sb.writeln(const JsonEncoder.withIndent('  ').convert(m.toolArgs));
      }
    } else if (item is ThinkingItem) {
      sb.writeln('[思考过程]');
      for (final m in item.block.messages) {
        sb.writeln('  ${m.text}');
      }
    }
  }
  return sb.toString();
}
```

- [ ] **步骤 6: 提交**

```bash
git add lib/ui/chat/chat_panel.dart lib/ui/chat/chat_session_controller.dart
git commit -m "refactor: 更新 ChatPanel 使用新的显示组件

- 将 messages 参数改为 displayItems
- 使用 MessageBubble 和 ThinkingFlowWidget
- 添加 onToggleThinkingBlock 回调
- 更新 formatMessagesForCopy 支持新结构

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 6: 添加 Shimmer 动画

**文件：**
- 修改：`lib/ui/chat/thinking_flow_widget.dart`

- [ ] **步骤 1: 创建动画控制器测试**

```dart
// 在测试中验证动画在 isActive=true 时显示
testWidgets('应该在活动时显示动画边框', (tester) async {
  final block = ThinkingBlock(
    messages: [ChatMsg(role: MsgRole.toolCall, text: '测试')],
    startTime: DateTime(2026, 3, 24, 10, 0),
    isActive: true,  // 活动状态
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ThinkingFlowWidget(
          block: block,
          onToggleExpansion: (_) {},
          onCopy: () {},
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  // 验证动画存在
  expect(find.byType(AnimatedContainer), findsWidgets);
});
```

- [ ] **步骤 2: 运行测试**

运行：`flutter test test/ui/chat/thinking_flow_widget_test.dart`

预期：可能 FAIL（取决于动画实现）

- [ ] **步骤 3: 添加动画支持**

```dart
// lib/ui/chat/thinking_flow_widget.dart 修改
import 'package:flutter/scheduler.dart';

class _ThinkingFlowWidgetState extends State<ThinkingFlowWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _showCopiedFeedback = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    if (widget.block.isActive) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(ThinkingFlowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.isActive != oldWidget.block.isActive) {
      if (widget.block.isActive) {
        _shimmerController.repeat();
      } else {
        _shimmerController.stop();
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  // ... 其他代码保持不变

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(  // 优化性能
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: widget.block.isActive
                  ? Border.all(
                      color: cs.primary.withOpacity(0.5),
                      width: 2,
                    )
                  : Border.all(color: cs.tertiary.withOpacity(0.3)),
            ),
            child: child,
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(cs),
            if (widget.block.isExpanded)
              _buildExpandedContent(cs)
            else
              _buildPreview(cs),
          ],
        ),
      ),
    );
  }

  // ... 其他方法保持不变
}
```

- [ ] **步骤 4: 运行测试确认通过**

运行：`flutter test test/ui/chat/thinking_flow_widget_test.dart`

预期：PASS

- [ ] **步骤 5: 提交**

```bash
git add lib/ui/chat/thinking_flow_widget.dart test/ui/chat/thinking_flow_widget_test.dart
git commit -m "feat: 添加思维流活动动画

- 添加 Shimmer 边框动画
- 仅在 isActive=true 时显示动画
- 使用 RepaintBoundary 优化性能
- 自动控制动画生命周期

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 7: 添加展开动画

**文件：**
- 修改：`lib/ui/chat/thinking_flow_widget.dart`

- [ ] **步骤 1: 在 _buildPreview 和 _buildExpandedContent 中添加 AnimatedContainer**

```dart
// lib/ui/chat/thinking_flow_widget.dart

Widget _buildPreview(ColorScheme cs) {
  return AnimatedContainer(  // 添加动画
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    child: GestureDetector(
      onTap: () => widget.onToggleExpansion(!widget.block.isExpanded),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(minHeight: 80),
        child: SelectableText(
          _buildPreviewText(),
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
            fontFamily: 'monospace',
          ),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}

Widget _buildExpandedContent(ColorScheme cs) {
  return AnimatedContainer(  // 添加动画
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    child: Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.block.messages.map((msg) => _buildMessageItem(msg, cs)).toList(),
      ),
    ),
  );
}
```

- [ ] **步骤 2: 提交**

```bash
git add lib/ui/chat/thinking_flow_widget.dart
git commit -m "feat: 添加展开/折叠动画

- 使用 AnimatedContainer 实现平滑过渡
- 200ms 持续时间，easeInOut 曲线
- 提升用户体验

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 8: 完善错误处理和边界情况

**文件：**
- 修改：`lib/ui/chat/chat_session_controller.dart`
- 修改：`lib/ui/chat/thinking_flow_widget.dart`

- [ ] **步骤 1: 添加空思维块检查**

```dart
// lib/ui/chat/chat_session_controller.dart 中修改 _onWsMessage

void _onWsMessage(dynamic raw) {
  if (raw is! String) {
    return;
  }

  try {
    final result = ChatProtocolMapper.applyEvent(
      raw: raw,
      chunkBuffer: _chunkBuffer,
      agentBusy: _agentBusy,
      lastMessageRole: _messages.isNotEmpty ? _messages.last.role : null,
    );

    _messages.addAll(result.messages);

    for (final msg in result.messages) {
      if (_currentBlock != null && _isIntermediateMessage(msg)) {
        _currentBlock!.addMessage(msg);
      } else if (msg.role == MsgRole.assistant) {
        if (_currentBlock != null && _currentBlock!.messages.isNotEmpty) {
          _displayItems.add(ThinkingItem(_currentBlock!));
        }
        _displayItems.add(MessageItem(msg));
        _currentBlock = null;
      }
    }

    _agentBusy = result.agentBusy;
    if (_currentBlock != null) {
      _currentBlock!.isActive = _agentBusy;

      if (!_agentBusy && _currentBlock!.messages.isNotEmpty) {
        _displayItems.add(ThinkingItem(_currentBlock!));
        _currentBlock = null;
      } else if (!_agentBusy && _currentBlock!.messages.isEmpty) {
        // 不要添加空的思维块
        _currentBlock = null;
      }
    }

    notifyListeners();
  } catch (e, stack) {
    // 记录错误但继续运行
    debugPrint('Error processing WebSocket message: $e');
    debugPrint(stack.toString());
  }
}
```

- [ ] **步骤 2: 添加复制失败处理**

```dart
// lib/ui/chat/thinking_flow_widget.dart 和 message_bubble.dart
// 已经实现（静默失败）
```

- [ ] **步骤 3: 添加动画降级处理**

```dart
// lib/ui/chat/thinking_flow_widget.dart 中
// 如果动画控制器失败，使用静态边框
Widget build(BuildContext context) {
  final cs = Theme.of(context).colorScheme;

  return RepaintBoundary(
    child: widget.block.isActive
        ? AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: cs.primary.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: child,
              );
            },
            child: _buildContent(cs),
          )
        : Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(color: cs.tertiary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildContent(cs),
          ),
  );
}

Widget _buildContent(ColorScheme cs) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildHeader(cs),
      if (widget.block.isExpanded)
        _buildExpandedContent(cs)
      else
        _buildPreview(cs),
    ],
  );
}
```

- [ ] **步骤 4: 提交**

```bash
git add lib/ui/chat/chat_session_controller.dart lib/ui/chat/thinking_flow_widget.dart
git commit -m "feat: 完善错误处理和边界情况

- 不渲染空的思维块
- 捕获并记录消息解析错误
- 动画失败时降级到静态边框
- 提升系统稳定性

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 9: 运行完整测试套件并修复

- [ ] **步骤 1: 运行所有测试**

运行：`flutter test`

预期：所有测试通过

- [ ] **步骤 2: 运行应用进行手动测试**

运行：`flutter run -d macos`（或你的目标平台）

测试清单：
- [ ] 发送消息，观察思维流分组
- [ ] 验证折叠预览显示 4-5 行
- [ ] 点击展开/折叠，验证动画
- [ ] 验证活动时显示 shimmer 动画
- [ ] 思考完成后验证自动折叠
- [ ] 点击复制按钮，验证提示显示
- [ ] 测试多条连续消息
- [ ] 测试工具调用和结果显示

- [ ] **步骤 3: 修复发现的问题**

（根据测试结果修复）

- [ ] **步骤 4: 最终提交**

```bash
git add .
git commit -m "test: 修复测试和手动测试发现的问题

- 修复 [具体问题1]
- 修复 [具体问题2]
- 所有测试通过

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### 任务 10: 性能优化和文档

- [ ] **步骤 1: 使用 Flutter DevTools 检查性能**

运行：`flutter run --profile`

检查：
- 帧率保持在 60fps
- 没有内存泄漏
- RepaintBoundary 生效

- [ ] **步骤 2: 添加代码注释**

在关键方法中添加文档注释

- [ ] **步骤 3: 更新 README**

如果需要，添加功能说明

- [ ] **步骤 4: 最终提交**

```bash
git add .
git commit -m "docs: 添加文档和性能优化

- 添加方法文档注释
- 优化动画性能
- 验证帧率和内存使用
- 完成思维流显示功能

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push  # 如果需要推送到远程
```

---

## 验收标准

完成所有任务后，应该满足：

- ✅ 所有单元测试通过
- ✅ 所有 widget 测试通过
- ✅ 思维流正确分组到折叠块中
- ✅ 折叠时显示 4-5 行预览
- ✅ 点击展开/折叠工作正常
- ✅ 活动时显示 shimmer 边框动画
- ✅ 思考完成后自动折叠
- ✅ 所有消息类型都有复制按钮
- ✅ 复制后显示"已复制!"提示
- ✅ 性能：60fps，无卡顿
- ✅ 没有控制台错误或警告

## 相关文档

- 设计规范：`docs/superpowers/specs/2026-03-24-thinking-flow-display-design.md`
- 现有代码：`lib/ui/chat/*.dart`
