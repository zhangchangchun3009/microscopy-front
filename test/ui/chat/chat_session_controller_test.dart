import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_session_controller.dart';
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
        '{"type":"tool_call_start","message_id":"m1","tool_name":"search","args":{"q":"abc"}}',
      );
      controller.handleIncomingEventForTest(
        '{"type":"tool_call_end","message_id":"m1","status":"success","result":"ok"}',
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

    test('disconnect 会清理连接状态但保留聚合结果', () {
      final controller = ChatSessionController();
      controller.handleIncomingEventForTest('{"type":"turn_start","message_id":"m1"}');
      controller.handleIncomingEventForTest('{"type":"turn_end","message_id":"m1"}');

      controller.disconnect();

      expect(controller.wsConnected, isFalse);
      expect(controller.agentBusy, isFalse);
      expect(controller.turns, isNotEmpty);
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
  });
}
