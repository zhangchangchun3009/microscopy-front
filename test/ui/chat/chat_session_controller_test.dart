import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_session_controller.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';
import 'package:microscope_app/ui/chat/chat_turn_models.dart';

void main() {
  group('ChatSessionController turn 聚合', () {
    test('按 message_id 聚合完整 turn 事件流', () {
      final controller = ChatSessionController();

      controller.handleIncomingEventForTest('{"type":"turn_start","message_id":"m1"}');
      controller.handleIncomingEventForTest(
        '{"type":"thought_update","message_id":"m1","text":"分析需求"}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"tool_call_start","message_id":"m1","step_id":"s1","tool_name":"search","args":{"q":"abc"}}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"tool_call_end","message_id":"m1","step_id":"s1","status":"success","result":"ok"}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"content_update","message_id":"m1","content":"你好"}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"content_update","message_id":"m1","content":"，世界"}',
      );
      controller.handleIncomingEventForTest('{"type":"turn_end","message_id":"m1"}');

      expect(controller.turns.length, 1);
      expect(controller.turnByMessageId['m1'], isNotNull);
      final turn = controller.turns.single;
      expect(turn.isFinished, isTrue);
      expect(turn.steps.map((s) => s.type).toList(), [
        StepType.thought,
        StepType.toolCall,
        StepType.content,
        StepType.done,
      ]);
      expect(turn.steps[2].text, '你好，世界');
    });

    test('未知 turn 的增量事件会自动创建 turn', () {
      final controller = ChatSessionController();

      controller.handleIncomingEventForTest(
        '{"type":"content_update","message_id":"m-auto","content":"hello"}',
      );

      expect(controller.turns.length, 1);
      expect(controller.turns.single.messageId, 'm-auto');
      expect(controller.turns.single.steps.single.type, StepType.content);
    });

    test('thought_delta 逐步追加且 thought_update 最终覆盖', () {
      final controller = ChatSessionController();

      controller.handleIncomingEventForTest('{"type":"turn_start","message_id":"m-stream"}');
      controller.handleIncomingEventForTest(
        '{"type":"thought_delta","message_id":"m-stream","delta":"正在"}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"thought_delta","message_id":"m-stream","delta":"分析"}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"thought_update","message_id":"m-stream","content":"正在分析完整上下文"}',
      );

      final thoughts = controller.turns.single.thoughtSteps;
      expect(thoughts.length, 1);
      expect(thoughts.single.text, '正在分析完整上下文');
    });

    test('连续 thought_update 保留完整思考步骤历史', () {
      final controller = ChatSessionController();

      controller.handleIncomingEventForTest('{"type":"turn_start","message_id":"m-thoughts"}');
      controller.handleIncomingEventForTest(
        '{"type":"thought_update","message_id":"m-thoughts","content":"第一段思考"}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"thought_update","message_id":"m-thoughts","content":"第二段思考"}',
      );

      final thoughts = controller.turns.single.thoughtSteps;
      expect(thoughts.length, 2);
      expect(thoughts[0].text, '第一段思考');
      expect(thoughts[1].text, '第二段思考');
    });

    test('disconnect 会清理连接状态但保留聚合结果', () {
      final controller = ChatSessionController();
      controller.handleIncomingEventForTest('{"type":"turn_start","message_id":"m1"}');
      controller.handleIncomingEventForTest('{"type":"turn_end","message_id":"m1"}');

      controller.disconnect();

      expect(controller.wsConnected, isFalse);
      expect(controller.agentBusy, isFalse);
      expect(controller.turns, isNotEmpty);
    });

    test('connect 写入「正在连接」后在 await ready 之前即触发 notify', () async {
      final controller = ChatSessionController();
      var notifications = 0;
      controller.addListener(() => notifications++);
      // 避免误连本机可能存在的 gateway（如 42617），用高位端口保证尽快失败或挂起在 ready
      final pending = controller.connect('ws://127.0.0.1:59998/ws/chat');
      expect(
        controller.messages.map((m) => m.text).any((t) => t.contains('正在连接')),
        isTrue,
      );
      // disconnect 一次 notify + 正在连接 一次 notify
      expect(notifications, greaterThanOrEqualTo(2));
      await pending;
    });

    test('formatMessagesForCopy 按时间将状态行排在相应对话前后', () {
      final controller = ChatSessionController();
      controller.appendStatusForTest('第一条连接日志', DateTime(2025, 1, 1));
      controller.handleIncomingEventForTest(
        '{"type":"content_update","message_id":"m-old","content":"较早的助手回复"}',
      );
      controller.appendStatusForTest('重连', DateTime(2026, 6, 1));

      final text = controller.formatMessagesForCopy();
      final iFirstStatus = text.indexOf('[状态] 第一条连接日志');
      final iAssistant = text.indexOf('[助手]');
      final iReconnect = text.indexOf('[状态] 重连');
      expect(iFirstStatus, lessThan(iAssistant));
      expect(iAssistant, lessThan(iReconnect));
    });

    test('并行 tool_call_end 按 step_id 归因，与到达顺序无关', () {
      final controller = ChatSessionController();
      controller.handleIncomingEventForTest('{"type":"turn_start","message_id":"m-p"}');
      controller.handleIncomingEventForTest(
        '{"type":"tool_call_start","message_id":"m-p","step_id":"id-a","tool_name":"get_system_status","args":{}}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"tool_call_start","message_id":"m-p","step_id":"id-b","tool_name":"check_incomplete_tasks","args":{}}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"tool_call_end","message_id":"m-p","step_id":"id-b","success":true,"result":"tasks-json"}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"tool_call_end","message_id":"m-p","step_id":"id-a","success":true,"result":"status-json"}',
      );
      controller.handleIncomingEventForTest('{"type":"turn_end","message_id":"m-p"}');

      final tools = controller.turns.single.steps.where((s) => s.type == StepType.toolCall).toList();
      expect(tools.length, 2);
      expect(tools[0].toolName, 'get_system_status');
      expect(tools[0].resultText, 'status-json');
      expect(tools[1].toolName, 'check_incomplete_tasks');
      expect(tools[1].resultText, 'tasks-json');
    });

    test('tool_call_end 含 result_image_base64 时写入预览字节', () {
      final controller = ChatSessionController();
      final b64 = base64Encode([10, 20, 30]);
      controller.handleIncomingEventForTest('{"type":"turn_start","message_id":"m-img"}');
      controller.handleIncomingEventForTest(
        '{"type":"tool_call_start","message_id":"m-img","step_id":"cap1","tool_name":"capture_image","args":{}}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"tool_call_end","message_id":"m-img","step_id":"cap1","success":true,"result":"{}",'
        '"result_image_base64":"$b64"}',
      );
      controller.handleIncomingEventForTest('{"type":"turn_end","message_id":"m-img"}');

      final toolStep = controller.turns.single.steps.firstWhere(
        (s) => s.type == StepType.toolCall,
      );
      expect(toolStep.previewImages.single, [10, 20, 30]);
    });

    test('buildOutboundMessagePayload 在有 ROI 时附带 roi_norm', () {
      final payload = ChatSessionController.buildOutboundMessagePayloadForTest(
        '请分析该区域',
        roiNorm: {
          'type': 'rect',
          'coords_norm': {'x': 0.2, 'y': 0.3, 'w': 0.4, 'h': 0.5},
        },
      );
      expect(payload['type'], 'message');
      expect(payload['content'], '请分析该区域');
      expect(payload['roi_norm'], isNotNull);
    });

    test('buildOutboundMessagePayload 无 ROI 时保持旧行为', () {
      final payload = ChatSessionController.buildOutboundMessagePayloadForTest(
        '不带 ROI 的消息',
      );
      expect(payload, {'type': 'message', 'content': '不带 ROI 的消息'});
    });
  });

  group('decodeToolPreviewImagesForTest', () {
    test('合法 base64 返回单元素列表', () {
      final out = ChatSessionController.decodeToolPreviewImagesForTest({
        'result_image_base64': base64Encode([1, 2, 3]),
      });
      expect(out.single, [1, 2, 3]);
    });

    test('缺省或非法字段返回空列表', () {
      expect(ChatSessionController.decodeToolPreviewImagesForTest({}), isEmpty);
      expect(
        ChatSessionController.decodeToolPreviewImagesForTest({
          'result_image_base64': '%%%',
        }),
        isEmpty,
      );
    });
  });

  group('ChatSessionController', () {
    test('should append system message to list', () {
      final controller = ChatSessionController();
      final initialCount = controller.systemMessages.length;

      controller.appendSystemMessageForTest(
        'Test system message',
        SystemMessageType.info,
      );

      expect(controller.systemMessages.length, initialCount + 1);
      expect(controller.systemMessages.last.content, 'Test system message');
      expect(controller.systemMessages.last.type, SystemMessageType.info);

      controller.dispose();
    });

    test('should track current message id', () {
      final controller = ChatSessionController();
      expect(controller.currentMessageId, null);

      controller.setCurrentMessageIdForTest('msg-123');

      expect(controller.currentMessageId, 'msg-123');

      controller.dispose();
    });
  });
}
