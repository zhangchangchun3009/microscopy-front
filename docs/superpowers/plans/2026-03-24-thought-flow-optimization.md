# 思维流显示优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-step. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标:** 通过基于 Turn-Step 的 WebSocket 协议重构，实现思维流消息的确定性聚合，提供类似 Google AI Studio 的用户体验。

**架构:** 后端在处理用户消息时生成 UUID (message_id)，所有后续事件（思考更新、工具调用、最终回复）都携带这个 ID。前端通过 message_id 将事件聚合到 ChatTurn 对象中，使用嵌套数据模型（thoughtSteps + finalContent）替代现有的平铺列表。

**技术栈:** Rust (后端), Dart/Flutter (前端), WebSocket, serde_json, ChangeNotifier

---

## 阶段 1: 后端 WebSocket 协议改造

### Task 1: 扩展 AgentStreamEvent 枚举

**文件:**
- Modify: `src/agent/loop_.rs` (AgentStreamEvent 定义附近)

- [ ] **Step 1: 添加新的事件类型变体**

在 `AgentStreamEvent` 枚举中添加新的变体，用于携带 message_id 的结构化事件：

```rust
pub enum AgentStreamEvent {
    // 新增：回合级事件（携带 message_id）
    TurnStart(String),  // message_id
    ThoughtUpdate(String, String),  // (message_id, content)
    ToolCallStart(String, String, String, serde_json::Value),  // (message_id, step_id, tool_name, args)
    ToolCallEnd(String, String, String, String, u64, bool),  // (message_id, step_id, tool_name, result, duration_ms, success)
    ContentUpdate(String, String),  // (message_id, content)
    TurnEnd(String),  // message_id

    // 保留原有的（向后兼容，后续移除）
    ToolCall { name: String, args: serde_json::Value },
    ToolResult { name: String, success: bool, output: String },
}
```

- [ ] **Step 2: 提交更改**

```bash
git add src/agent/loop_.rs
git commit -m "feat(agent): add turn-based event types to AgentStreamEvent

新增 TurnStart, ThoughtUpdate, ToolCallStart, ToolCallEnd,
ContentUpdate, TurnEnd 事件类型，用于携带 message_id 的
结构化消息流。"
```

---

### Task 2: 修改 agent loop 生成 message_id

**文件:**
- Modify: `src/agent/loop_.rs` (process_message_with_history_and_system_prompt 函数)

- [ ] **Step 1: 在函数签名中添加 message_id 参数**

找到 `process_message_with_history_and_system_prompt` 函数，修改签名以接收和返回 message_id：

```rust
pub async fn process_message_with_history_and_system_prompt(
    config: Config,
    user_content: &str,
    prior: &[ChatMessage],
    extra_system_prompt: Option<&str>,
    delta_tx: Option<mpsc::Sender<String>>,
    event_tx: Option<mpsc::UnboundedSender<AgentStreamEvent>>,
    message_id: String,  // 新增参数
) -> Result<ProcessMessageResult>
```

- [ ] **Step 2: 提交更改**

```bash
git add src/agent/loop_.rs
git commit -m "refactor(agent): add message_id parameter to process_message_with_history_and_system_prompt"
```

---

### Task 3: 在 WebSocket handler 中生成 UUID

**文件:**
- Modify: `src/gateway/ws.rs` (run_ws_turn_with_stream 函数)

- [ ] **Step 1: 在调用前生成 message_id**

在 `run_ws_turn_with_stream` 函数中，调用 `process_message_with_history_and_system_prompt` 之前生成 UUID：

```rust
async fn run_ws_turn_with_stream(
    sender: &mut futures_util::stream::SplitSink<WebSocket, Message>,
    config: crate::config::Config,
    content: &str,
    prior: &[ChatMessage],
    session_prompt: Option<&str>,
    timeout_budget_secs: u64,
) -> WsTurnExecution {
    let (delta_tx, mut delta_rx) = mpsc::channel::<String>(128);
    let (event_tx, mut event_rx) = mpsc::unbounded_channel::<AgentStreamEvent>();

    // 新增：生成 message_id
    let message_id = Uuid::new_v4().to_string();

    // 发送 turn_start 事件
    let _ = event_tx.send(AgentStreamEvent::TurnStart(message_id.clone()));

    let mut process_future = std::pin::pin!(process_message_with_history_and_system_prompt(
        config,
        content,
        prior,
        session_prompt,
        Some(delta_tx),
        Some(event_tx),
        message_id,  // 传入 message_id
    ));
    // ... 其余代码保持不变
}
```

- [ ] **Step 2: 提交更改**

```bash
git add src/gateway/ws.rs
git commit -m "feat(ws): generate message_id and send TurnStart event

在 WebSocket handler 中生成 UUID 作为 message_id，并在开始处理
用户消息时发送 TurnStart 事件。"
```

---

### Task 4: 更新 WebSocket 事件序列化逻辑

**文件:**
- Modify: `src/gateway/ws.rs` (run_ws_turn_with_stream 函数中的 tokio::select! 循环)

- [ ] **Step 1: 更新事件处理以序列化新的事件类型**

找到 `tokio::select!` 循环中的 `Some(event) = event_rx.recv()` 分支，更新为：

```rust
Some(event) = event_rx.recv() => {
    let payload = match event {
        AgentStreamEvent::TurnStart(msg_id) => {
            serde_json::json!({
                "message_id": msg_id,
                "type": "turn_start",
                "role": "assistant"
            })
        }
        AgentStreamEvent::ThoughtUpdate(msg_id, content) => {
            serde_json::json!({
                "message_id": msg_id,
                "type": "thought_update",
                "content": content
            })
        }
        AgentStreamEvent::ToolCallStart(msg_id, step_id, tool_name, args) => {
            serde_json::json!({
                "message_id": msg_id,
                "type": "tool_call_start",
                "step_id": step_id,
                "tool_name": tool_name,
                "args": args
            })
        }
        AgentStreamEvent::ToolCallEnd(msg_id, step_id, tool_name, result, duration_ms, success) => {
            serde_json::json!({
                "message_id": msg_id,
                "type": "tool_call_end",
                "step_id": step_id,
                "tool_name": tool_name,
                "result": result,
                "duration_ms": duration_ms,
                "success": success
            })
        }
        AgentStreamEvent::ContentUpdate(msg_id, content) => {
            serde_json::json!({
                "message_id": msg_id,
                "type": "content_update",
                "content": content
            })
        }
        AgentStreamEvent::TurnEnd(msg_id) => {
            serde_json::json!({
                "message_id": msg_id,
                "type": "turn_end"
            })
        }
        // 保留原有的兼容性处理
        AgentStreamEvent::ToolCall { name, args } => {
            serde_json::json!({
                "type": "tool_call",
                "name": name,
                "args": args
            })
        }
        AgentStreamEvent::ToolResult { name, success, output } => {
            serde_json::json!({
                "type": "tool_result",
                "name": name,
                "success": success,
                "output": output
            })
        }
    };
    let _ = sender.send(Message::Text(payload.to_string().into())).await;
}
```

- [ ] **Step 2: 提交更改**

```bash
git add src/gateway/ws.rs
git commit -m "feat(ws): serialize new turn-based events to WebSocket

更新 WebSocket 事件序列化逻辑，支持新的 TurnStart、ThoughtUpdate、
ToolCallStart、ToolCallEnd、ContentUpdate、TurnEnd 事件类型。"
```

---

### Task 5: 调整超时配置为 120 秒

**文件:**
- Modify: `src/gateway/ws.rs`

- [ ] **Step 1: 找到超时相关常量定义**

检查文件中的超时配置，确保使用 120 秒作为请求超时。如果需要，更新 `WS_MESSAGE_TIMEOUT_SCALE_CAP` 或相关配置。

- [ ] **Step 2: 确认配置合理**

验证超时配置在代码注释或文档中说明为 120 秒（针对慢速模型）。

- [ ] **Step 3: 提交更改（如有修改）**

```bash
git add src/gateway/ws.rs
git commit -m "config(ws): adjust timeout to 120s for slow models

将 WebSocket 请求超时调整为 120 秒，以适配慢速 LLM 模型。"
```

---

### Task 6: 添加后端单元测试

**文件:**
- Create: `src/gateway/ws_a16_tests.rs` (在现有测试文件中添加)

- [ ] **Step 1: 添加 message_id 一致性测试**

```rust
#[tokio::test]
async fn test_turn_events_share_same_message_id() {
    // 验证同一回合的所有事件使用相同的 message_id
    // 这个测试需要模拟 agent loop 并捕获所有事件
}
```

- [ ] **Step 2: 添加事件序列化测试**

```rust
#[tokio::test]
async fn test_turn_start_event_serialization() {
    let msg_id = Uuid::new_v4().to_string();
    let event = AgentStreamEvent::TurnStart(msg_id.clone());
    let payload = match event {
        AgentStreamEvent::TurnStart(id) => {
            serde_json::json!({
                "message_id": id,
                "type": "turn_start",
                "role": "assistant"
            })
        }
        _ => unreachable!(),
    };

    assert_eq!(payload["message_id"], msg_id);
    assert_eq!(payload["type"], "turn_start");
    assert_eq!(payload["role"], "assistant");
}
```

- [ ] **Step 3: 运行测试**

```bash
cargo test --package zeroclaw ws_turn
```

Expected: PASS

- [ ] **Step 4: 提交测试**

```bash
git add src/gateway/ws_a16_tests.rs
git commit -m "test(ws): add unit tests for turn-based events

添加 message_id 一致性测试和事件序列化测试。"
```

---

## 阶段 2: 前端数据模型重构

### Task 7: 创建新的数据模型文件

**文件:**
- Create: `microscopy-front/lib/ui/chat/chat_turn_models.dart`

- [ ] **Step 1: 创建枚举和数据类**

```dart
import 'package:flutter/foundation.dart';

/// 思考步骤类型
enum StepType { text, tool }

/// 工具调用状态
enum ToolStatus { running, success, error }

/// 单个思考步骤
class ThoughtStep {
  final String? id; // step_id
  final StepType type;
  String content;
  final String? toolName;
  final String? toolResult;
  ToolStatus? status;
  int? durationMs;

  ThoughtStep({
    this.id,
    required this.type,
    this.content = '',
    this.toolName,
    this.status,
  });
}

/// 完整的对话回合
class ChatTurn extends ChangeNotifier {
  final String id; // message_id
  final String role; // 'user' or 'assistant'
  final DateTime startTime;

  // 思考过程和工具调用
  final List<ThoughtStep> thoughtSteps = [];

  // 最终回复文本
  String finalContent = '';

  // 状态
  bool isComplete = false;
  bool isExpanded = false; // UI 展开状态

  ChatTurn({
    required this.id,
    required this.role,
    DateTime? startTime,
  }) : this.startTime = startTime ?? DateTime.now();

  /// 聚合思考文本（连续的思考合并为一个步骤）
  void addThoughtText(String text) {
    if (thoughtSteps.isEmpty || thoughtSteps.last.type != StepType.text) {
      thoughtSteps.add(ThoughtStep(type: StepType.text, content: text));
    } else {
      thoughtSteps.last.content += text;
    }
    notifyListeners();
  }

  /// 开始工具调用
  void startToolCall(String stepId, String toolName, Map<String, dynamic>? args) {
    thoughtSteps.add(ThoughtStep(
      id: stepId,
      type: StepType.tool,
      toolName: toolName,
      content: '调用工具: $toolName',
      status: ToolStatus.running,
    ));
    notifyListeners();
  }

  /// 结束工具调用（成功）
  void endToolCall(String stepId, int duration, String result) {
    final step = thoughtSteps.cast<ThoughtStep?>().firstWhere(
      (s) => s?.id == stepId,
      orElse: () => null,
    );
    if (step != null) {
      step.status = ToolStatus.success;
      step.durationMs = duration;
      step.toolResult = result;
      step.content = '✓ ${step.toolName} (${duration}ms)';
      notifyListeners();
    }
  }

  /// 结束工具调用（失败）
  void endToolCallWithError(String stepId, int duration, String error) {
    final step = thoughtSteps.cast<ThoughtStep?>().firstWhere(
      (s) => s?.id == stepId,
      orElse: () => null,
    );
    if (step != null) {
      step.status = ToolStatus.error;
      step.durationMs = duration;
      step.toolResult = error;
      step.content = '✗ ${step.toolName} 失败';
      notifyListeners();
    }
  }

  /// 追加最终回复内容
  void appendContent(String text) {
    finalContent += text;
    notifyListeners();
  }

  /// 标记回合完成
  void finish() {
    isComplete = true;
    notifyListeners();
  }

  /// 切换展开状态
  void toggleExpanded() {
    isExpanded = !isExpanded;
    notifyListeners();
  }
}
```

- [ ] **Step 2: 提交新文件**

```bash
cd ../microscopy-front
git add lib/ui/chat/chat_turn_models.dart
git commit -m "feat(chat): add ChatTurn and ThoughtStep models

新增嵌套数据模型用于聚合思维流消息：
- ChatTurn: 完整的对话回合，包含 thoughtSteps 和 finalContent
- ThoughtStep: 单个思考步骤（文本或工具调用）
- 支持 message_id 确定性聚合"
```

---

### Task 8: 重构 ChatSessionController（核心逻辑）

**文件:**
- Modify: `microscopy-front/lib/ui/chat/chat_session_controller.dart`

- [ ] **Step 1: 替换数据结构**

将 `_messages` 和 `_displayItems` 替换为新的结构：

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'chat_models.dart';
import 'chat_turn_models.dart';

class ChatSessionController extends ChangeNotifier {
  // 替换原有的消息列表
  final Map<String, ChatTurn> _turns = {};
  final List<ChatTurn> _turnList = []; // 保持插入顺序

  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  bool _wsConnected = false;
  String? _currentTurnId; // 当前正在处理的回合 ID

  // Getter
  List<ChatTurn> get turns => List.unmodifiable(_turnList);
  bool get wsConnected => _wsConnected;
```

- [ ] **Step 2: 重写 _onWsMessage 方法**

完全替换 `_onWsMessage` 方法为新的分发逻辑：

```dart
  void _onWsMessage(dynamic raw) {
    if (raw is! String) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final msgId = data['message_id'] as String?;
      final type = data['type'] as String?;

      if (msgId == null || type == null) return;

      switch (type) {
        case 'turn_start':
          _handleTurnStart(msgId, data['role'] as String? ?? 'assistant');
          break;
        case 'thought_update':
          _handleThoughtUpdate(msgId, data['content'] as String? ?? '');
          break;
        case 'tool_call_start':
          _handleToolCallStart(
            msgId,
            data['step_id'] as String,
            data['tool_name'] as String,
            data['args'] as Map<String, dynamic>?,
          );
          break;
        case 'tool_call_end':
          _handleToolCallEnd(
            msgId,
            data['step_id'] as String,
            data['duration_ms'] as int,
            data['result'] as String? ?? '',
            data['success'] as bool? ?? true,
          );
          break;
        case 'content_update':
          _handleContentUpdate(msgId, data['content'] as String? ?? '');
          break;
        case 'turn_end':
          _handleTurnEnd(msgId);
          break;
      }

      notifyListeners();
    } catch (e, stack) {
      debugPrint('Error processing WebSocket message: $e');
      debugPrint(stack.toString());
    }
  }
```

- [ ] **Step 3: 实现事件处理方法**

在类中添加所有处理方法：

```dart
  void _handleTurnStart(String msgId, String role) {
    final turn = ChatTurn(id: msgId, role: role);
    _turns[msgId] = turn;
    _turnList.add(turn);
    _currentTurnId = msgId;
  }

  void _handleThoughtUpdate(String msgId, String content) {
    if (!_turns.containsKey(msgId)) {
      debugPrint('Warning: received event for unknown turn: $msgId');
      _handleTurnStart(msgId, 'assistant');
    }
    _turns[msgId]?.addThoughtText(content);
  }

  void _handleToolCallStart(
    String msgId,
    String stepId,
    String toolName,
    Map<String, dynamic>? args,
  ) {
    if (!_turns.containsKey(msgId)) {
      debugPrint('Warning: received event for unknown turn: $msgId');
      _handleTurnStart(msgId, 'assistant');
    }
    _turns[msgId]?.startToolCall(stepId, toolName, args);
  }

  void _handleToolCallEnd(
    String msgId,
    String stepId,
    int duration,
    String result,
    bool success,
  ) {
    if (!_turns.containsKey(msgId)) {
      debugPrint('Warning: received event for unknown turn: $msgId');
      return;
    }
    if (success) {
      _turns[msgId]?.endToolCall(stepId, duration, result);
    } else {
      _turns[msgId]?.endToolCallWithError(stepId, duration, result);
    }
  }

  void _handleContentUpdate(String msgId, String content) {
    if (!_turns.containsKey(msgId)) {
      debugPrint('Warning: received event for unknown turn: $msgId');
      _handleTurnStart(msgId, 'assistant');
    }
    _turns[msgId]?.appendContent(content);
  }

  void _handleTurnEnd(String msgId) {
    if (!_turns.containsKey(msgId)) {
      debugPrint('Warning: received turn_end for unknown turn: $msgId');
      return;
    }
    _turns[msgId]?.finish();
    _currentTurnId = null;
  }
```

- [ ] **Step 4: 移除废弃代码**

删除以下不再需要的方法：
- `_categorizeMessageByPattern`
- `_processMessageGrouping`
- `_updateCurrentBlockActivity`
- `_isIntermediateMessage`

删除以下字段：
- `_chunkBuffer`
- `_agentBusy`
- `_currentBlock`

- [ ] **Step 5: 更新 sendMessage 方法**

简化 `sendMessage` 方法，移除复杂的分组逻辑：

```dart
  void sendMessage(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty || !_wsConnected) {
      return;
    }

    // 用户消息不经过 WebSocket 传输，直接添加到列表
    final userTurn = ChatTurn(id: DateTime.now().millisecondsSinceEpoch.toString(), role: 'user');
    userTurn.finalContent = normalized;
    userTurn.isComplete = true;
    _turns[userTurn.id] = userTurn;
    _turnList.add(userTurn);

    _channel?.sink.add(jsonEncode({'type': 'message', 'content': normalized}));
    notifyListeners();
  }
```

- [ ] **Step 6: 更新 disconnect 方法**

```dart
  void disconnect() {
    _wsSub?.cancel();
    _wsSub = null;
    _channel?.sink.close();
    _channel = null;
    _wsConnected = false;
    _currentTurnId = null;

    // 标记所有进行中的回合为失败
    for (final turn in _turns.values) {
      if (!turn.isComplete) {
        turn.isComplete = true;
      }
    }

    notifyListeners();
  }
```

- [ ] **Step 7: 提交更改**

```bash
git add lib/ui/chat/chat_session_controller.dart
git commit -m "refactor(chat): rewrite controller with turn-based aggregation

使用 message_id 进行确定性聚合：
- 移除文本模式识别和复杂分组逻辑
- 通过 Map<String, ChatTurn> 按 ID 直接查找更新
- 简化事件处理，每个事件类型有独立的处理方法"
```

---

### Task 9: 添加前端单元测试

**文件:**
- Create: `microscopy-front/test/ui/chat/chat_turn_models_test.dart`

- [ ] **Step 1: 创建 ChatTurn 测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:microscopy/ui/chat/chat_turn_models.dart';

void main() {
  group('ChatTurn', () {
    test('should aggregate thought updates', () {
      final turn = ChatTurn(id: 'test-1', role: 'assistant');
      turn.addThoughtText('思考1');
      turn.addThoughtText('思考2');

      expect(turn.thoughtSteps.length, 2);
      expect(turn.thoughtSteps[0].content, '思考1');
      expect(turn.thoughtSteps[1].content, '思考2');
    });

    test('should merge consecutive thought texts', () {
      final turn = ChatTurn(id: 'test-2', role: 'assistant');
      turn.addThoughtText('第一段');
      turn.addThoughtText(' 第二段');

      expect(turn.thoughtSteps.length, 1);
      expect(turn.thoughtSteps[0].content, '第一段 第二段');
    });

    test('should track tool call lifecycle', () {
      final turn = ChatTurn(id: 'test-3', role: 'assistant');
      turn.startToolCall('step-1', 'fast_focus', {});

      expect(turn.thoughtSteps.length, 1);
      expect(turn.thoughtSteps[0].status, ToolStatus.running);
      expect(turn.thoughtSteps[0].toolName, 'fast_focus');

      turn.endToolCall('step-1', 1300, '成功');

      expect(turn.thoughtSteps[0].status, ToolStatus.success);
      expect(turn.thoughtSteps[0].durationMs, 1300);
      expect(turn.thoughtSteps[0].toolResult, '成功');
    });

    test('should append final content', () {
      final turn = ChatTurn(id: 'test-4', role: 'assistant');
      turn.appendContent('Hello');
      turn.appendContent(' World');

      expect(turn.finalContent, 'Hello World');
    });

    test('should mark as complete', () {
      final turn = ChatTurn(id: 'test-5', role: 'assistant');
      expect(turn.isComplete, false);

      turn.finish();
      expect(turn.isComplete, true);
    });
  });
}
```

- [ ] **Step 2: 创建 Controller 测试**

```dart
// Create: test/ui/chat/chat_session_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:microscopy/ui/chat/chat_session_controller.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void main() {
  group('ChatSessionController', () {
    test('should aggregate events by message_id', () {
      final controller = ChatSessionController();

      // 模拟 WebSocket 消息序列
      controller._onWsMessage('{"message_id":"msg-1","type":"turn_start","role":"assistant"}');
      controller._onWsMessage('{"message_id":"msg-1","type":"thought_update","content":"思考中"}');
      controller._onWsMessage('{"message_id":"msg-1","type":"turn_end"}');

      expect(controller.turns.length, 1);
      expect(controller.turns.first.thoughtSteps.length, 1);
      expect(controller.turns.first.isComplete, true);
    });

    test('should handle multiple turns independently', () {
      final controller = ChatSessionController();

      controller._onWsMessage('{"message_id":"msg-1","type":"turn_start","role":"assistant"}');
      controller._onWsMessage('{"message_id":"msg-1","type":"content_update","content":"回复1"}');

      controller._onWsMessage('{"message_id":"msg-2","type":"turn_start","role":"assistant"}');
      controller._onWsMessage('{"message_id":"msg-2","type":"content_update","content":"回复2"}');

      expect(controller.turns.length, 2);
      expect(controller.turns[0].finalContent, '回复1');
      expect(controller.turns[1].finalContent, '回复2');
    });
  });
}
```

- [ ] **Step 3: 运行测试**

```bash
flutter test test/ui/chat/chat_turn_models_test.dart
flutter test test/ui/chat/chat_session_controller_test.dart
```

Expected: PASS

- [ ] **Step 4: 提交测试**

```bash
git add test/ui/chat/
git commit -m "test(chat): add unit tests for ChatTurn and Controller

添加数据模型和控制器的单元测试，覆盖：
- 思考文本聚合
- 工具调用生命周期
- message_id 事件聚合
- 多回合独立处理"
```

---

## 阶段 3: 前端 UI 适配

### Task 10: 创建 TurnBubble 组件

**文件:**
- Create: `microscopy-front/lib/ui/chat/turn_bubble.dart`

- [ ] **Step 1: 实现 TurnBubble 组件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'chat_turn_models.dart';

class TurnBubble extends StatefulWidget {
  final ChatTurn turn;
  final VoidCallback onCopy;

  const TurnBubble({
    super.key,
    required this.turn,
    required this.onCopy,
  });

  @override
  State<TurnBubble> createState() => _TurnBubbleState();
}

class _TurnBubbleState extends State<TurnBubble> {
  bool _showCopiedFeedback = false;

  void _handleCopy() async {
    widget.onCopy();
    try {
      await Clipboard.setData(ClipboardData(text: widget.turn.finalContent));
      setState(() => _showCopiedFeedback = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
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

    return AnimatedBuilder(
      animation: widget.turn,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.turn.role == 'user'
                ? cs.primary
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: widget.turn.thoughtSteps.isNotEmpty &&
                    !widget.turn.isComplete
                ? Border.all(
                    color: cs.primary.withValues(alpha: 0.5),
                    width: 2,
                  )
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 思考过程区块（如果有）
              if (widget.turn.thoughtSteps.isNotEmpty)
                _buildThinkingBlock(cs),

              // 2. 最终回复内容（如果有）
              if (widget.turn.finalContent.isNotEmpty) ...[
                if (widget.turn.thoughtSteps.isNotEmpty)
                  const Divider(height: 16),
                SelectableText(
                  widget.turn.finalContent,
                  style: TextStyle(
                    color: widget.turn.role == 'user'
                        ? cs.onPrimary
                        : cs.onSurface,
                    fontSize: 15,
                  ),
                ),
              ],

              // 3. 加载指示器（如果还在进行中）
              if (!widget.turn.isComplete &&
                  widget.turn.finalContent.isEmpty &&
                  widget.turn.thoughtSteps.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThinkingBlock(ColorScheme cs) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: false, // 始终折叠
        tilePadding: EdgeInsets.zero,
        title: Row(
          children: [
            Icon(
              !widget.turn.isComplete
                  ? Icons.psychology_outlined
                  : Icons.check_circle_outline,
              color: cs.tertiary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              !widget.turn.isComplete ? '思考中...' : '思考过程',
              style: TextStyle(
                fontSize: 12,
                color: cs.tertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${widget.turn.thoughtSteps.length} 步',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        children: widget.turn.thoughtSteps
            .map((step) => _buildStepItem(step, cs))
            .toList(),
      ),
    );
  }

  Widget _buildStepItem(ThoughtStep step, ColorScheme cs) {
    if (step.type == StepType.text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: cs.tertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                step.content,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 工具调用
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            if (step.status == ToolStatus.running)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            if (step.status == ToolStatus.success)
              Icon(Icons.check, color: Colors.green, size: 16),
            if (step.status == ToolStatus.error)
              Icon(Icons.close, color: cs.error, size: 16),
            const SizedBox(width: 8),
            Text(
              step.toolName ?? '未知工具',
              style: const TextStyle(fontSize: 13),
            ),
            if (step.durationMs != null) ...[
              const Spacer(),
              Text(
                '${step.durationMs}ms',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      );
    }
  }
}
```

- [ ] **Step 2: 提交组件**

```bash
git add lib/ui/chat/turn_bubble.dart
git commit -m "feat(ui): add TurnBubble component

新增 TurnBubble 组件用于渲染 ChatTurn：
- 支持思考过程折叠展示（默认折叠）
- 工具调用状态指示（running/success/error）
- 实时更新（基于 ChangeNotifier）
- 复制功能"
```

---

### Task 11: 修改 ChatPanel 使用新组件

**文件:**
- Modify: `microscopy-front/lib/ui/chat/chat_panel.dart`

- [ ] **Step 1: 更新 imports**

添加新的导入：

```dart
import 'chat_turn_models.dart';
import 'turn_bubble.dart';
```

- [ ] **Step 2: 更新 ListView.builder**

将消息列表改为渲染 `TurnBubble`：

```dart
// 找到 ListView.builder，替换为：
ListView.builder(
  itemCount: controller.turns.length,
  itemBuilder: (context, index) {
    final turn = controller.turns[index];
    return TurnBubble(
      turn: turn,
      onCopy: () => _copyTurn(turn),
    );
  },
)
```

- [ ] **Step 3: 更新复制方法**

```dart
void _copyTurn(ChatTurn turn) {
  // 可以扩展为复制完整内容（包括思考过程）
  // 目前只复制最终回复
  Clipboard.setData(ClipboardData(text: turn.finalContent));
  // 显示提示...
}
```

- [ ] **Step 4: 移除废弃的组件引用**

如果不再使用 `MessageBubble`、`ThinkingFlowWidget` 等组件，移除相关导入。

- [ ] **Step 5: 提交更改**

```bash
git add lib/ui/chat/chat_panel.dart
git commit -m "refactor(ui): adapt ChatPanel to use TurnBubble

- 使用 turns 替代原有的 messages/displayItems
- 渲染 TurnBubble 组件
- 移除废弃的组件引用"
```

---

### Task 12: 移除废弃文件（可选）

**文件:**
- Delete: `lib/ui/chat/thinking_flow_widget.dart` (如果不再使用)
- Delete: `lib/ui/chat/chat_display_models.dart` (如果不再使用)
- Delete: `lib/ui/chat/message_bubble.dart` (如果不再使用)

- [ ] **Step 1: 确认没有其他引用**

搜索这些文件的引用，确保可以安全删除：

```bash
grep -r "thinking_flow_widget" lib/
grep -r "chat_display_models" lib/
grep -r "message_bubble" lib/
```

- [ ] **Step 2: 删除废弃文件**

```bash
git rm lib/ui/chat/thinking_flow_widget.dart
git rm lib/ui/chat/chat_display_models.dart
git rm lib/ui/chat/message_bubble.dart
```

- [ ] **Step 3: 提交删除**

```bash
git commit -m "refactor(chat): remove obsolete components

移除不再使用的组件：
- ThinkingFlowWidget
- ChatDisplayItem/ThinkingBlock
- MessageBubble

已被 TurnBubble 替代"
```

---

## 阶段 4: 集成测试和调试

### Task 13: 端到端测试

- [ ] **Step 1: 启动后端**

```bash
cd ../microclaw
cargo run --bin zeroclaw
```

- [ ] **Step 2: 启动前端**

```bash
cd ../microscopy-front
flutter run
```

- [ ] **Step 3: 测试完整流程**

测试场景：
1. 发送简单消息，观察回复是否正常显示
2. 发送需要工具调用的消息（如"聚焦显微镜"），观察：
   - 思考过程是否折叠在"思考中..."区块
   - 工具调用状态是否实时更新（running → success）
   - 最终回复是否正确显示
3. 测试展开/折叠思考过程
4. 测试复制功能
5. 测试长消息的流式输出
6. 测试多个工具调用的显示

- [ ] **Step 4: 测试边界情况**

测试场景：
1. WebSocket 断开重连
2. 空回复（没有思考也没有内容）
3. 工具调用失败
4. 超时场景（120 秒）
5. 快速发送多条消息

- [ ] **Step 5: 记录问题**

创建一个文档记录发现的问题和修复方案。

---

### Task 14: 性能优化

- [ ] **Step 1: 检查 Flutter 性能**

使用 Flutter DevTools 检查：
- 是否有过度重绘
- 内存使用是否正常
- 列表滚动是否流畅

- [ ] **Step 2: 优化问题**

根据 DevTools 分析结果进行优化：
- 使用 `RepaintBoundary` 隔离重绘区域
- 确保 `notifyListeners()` 只在必要时调用
- 优化长列表渲染（如需要）

- [ ] **Step 3: 提交优化**

```bash
git commit -a -m "perf(chat): optimize rendering performance
"
```

---

### Task 15: 更新文档（可选）

- [ ] **Step 1: 更新协议文档**

如果项目有 WebSocket 协议文档，更新为新的事件格式。

- [ ] **Step 2: 更新 README 或 CHANGELOG**

记录这次重大改动。

- [ ] **Step 3: 提交文档更新**

```bash
git commit -a -m "docs: update WebSocket protocol documentation
"
```

---

## 完成检查清单

- [ ] 所有单元测试通过
- [ ] 端到端测试通过
- [ ] 边界情况测试通过
- [ ] 性能测试通过
- [ ] 代码已提交并推送
- [ ] 文档已更新（如需要）

---

## 预期结果

完成后，前端应该能够：
1. 可靠地聚合属于同一个回合的所有消息
2. 默认折叠思考过程，界面整洁
3. 实时显示工具调用状态
4. 支持展开查看完整的思考过程
5. 代码结构清晰，易于维护和扩展
