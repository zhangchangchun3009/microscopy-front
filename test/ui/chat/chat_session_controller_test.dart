import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_session_controller.dart';

void main() {
  group('ChatSessionController', () {
    test('should initialize with empty state', () {
      final controller = ChatSessionController();

      expect(controller.turns, isEmpty);
      expect(controller.wsConnected, false);
      expect(controller.agentBusy, false);
    });

    test('should handle turn_start event', () {
      final controller = ChatSessionController();

      controller.testOnWsMessage('{"message_id":"msg-1","type":"turn_start","role":"assistant"}');

      expect(controller.turns.length, 1);
      expect(controller.turns.first.id, 'msg-1');
      expect(controller.turns.first.role, 'assistant');
      expect(controller.agentBusy, true);
    });

    test('should aggregate thought updates by message_id', () {
      final controller = ChatSessionController();

      controller.testOnWsMessage('{"message_id":"msg-1","type":"turn_start","role":"assistant"}');
      controller.testOnWsMessage('{"message_id":"msg-1","type":"thought_update","content":"思考中"}');
      // Add a tool call to separate text blocks
      controller.testOnWsMessage('{"message_id":"msg-1","type":"tool_call_start","step_id":"step-1","tool_name":"tool1","args":{}}');
      controller.testOnWsMessage('{"message_id":"msg-1","type":"thought_update","content":"继续思考"}');

      expect(controller.turns.length, 1);
      expect(controller.turns.first.thoughtSteps.length, 3); // text + tool + text
      expect(controller.turns.first.thoughtSteps[0].content, '思考中');
      expect(controller.turns.first.thoughtSteps[1].toolName, 'tool1');
      expect(controller.turns.first.thoughtSteps[2].content, '继续思考');
    });

    test('should handle tool call lifecycle', () {
      final controller = ChatSessionController();

      controller.testOnWsMessage('{"message_id":"msg-1","type":"turn_start","role":"assistant"}');
      controller.testOnWsMessage('{"message_id":"msg-1","type":"tool_call_start","step_id":"step-1","tool_name":"fast_focus","args":{}}');
      controller.testOnWsMessage('{"message_id":"msg-1","type":"tool_call_end","step_id":"step-1","duration_ms":1300,"result":"成功","success":true}');

      expect(controller.turns.length, 1);
      expect(controller.turns.first.thoughtSteps.length, 1);
      expect(controller.turns.first.thoughtSteps[0].type.toString(), contains('tool'));
      expect(controller.turns.first.thoughtSteps[0].toolName, 'fast_focus');
      expect(controller.turns.first.thoughtSteps[0].status.toString(), contains('success'));
      expect(controller.turns.first.thoughtSteps[0].durationMs, 1300);
    });

    test('should handle content updates', () {
      final controller = ChatSessionController();

      controller.testOnWsMessage('{"message_id":"msg-1","type":"turn_start","role":"assistant"}');
      controller.testOnWsMessage('{"message_id":"msg-1","type":"content_update","content":"Hello"}');
      controller.testOnWsMessage('{"message_id":"msg-1","type":"content_update","content":" World"}');

      expect(controller.turns.length, 1);
      expect(controller.turns.first.finalContent, 'Hello World');
    });

    test('should mark turn as complete on turn_end', () {
      final controller = ChatSessionController();

      controller.testOnWsMessage('{"message_id":"msg-1","type":"turn_start","role":"assistant"}');
      controller.testOnWsMessage('{"message_id":"msg-1","type":"turn_end"}');

      expect(controller.turns.length, 1);
      expect(controller.turns.first.isComplete, true);
      expect(controller.agentBusy, false);
    });

    test('should handle multiple turns independently', () {
      final controller = ChatSessionController();

      controller.testOnWsMessage('{"message_id":"msg-1","type":"turn_start","role":"assistant"}');
      controller.testOnWsMessage('{"message_id":"msg-1","type":"content_update","content":"回复1"}');
      controller.testOnWsMessage('{"message_id":"msg-2","type":"turn_start","role":"assistant"}');
      controller.testOnWsMessage('{"message_id":"msg-2","type":"content_update","content":"回复2"}');

      expect(controller.turns.length, 2);
      expect(controller.turns[0].finalContent, '回复1');
      expect(controller.turns[1].finalContent, '回复2');
    });

    test('should ignore sending when disconnected', () {
      final controller = ChatSessionController();

      // When disconnected, sendMessage should be ignored
      controller.sendMessage('Test message');

      expect(controller.turns.length, 0);
    });

    test('should auto-create turn on orphaned thought event', () {
      final controller = ChatSessionController();

      // Send thought without turn_start
      controller.testOnWsMessage('{"message_id":"msg-1","type":"thought_update","content":"思考"}');

      expect(controller.turns.length, 1);
      expect(controller.turns.first.thoughtSteps.length, 1);
      expect(controller.turns.first.thoughtSteps[0].content, '思考');
    });

    test('should auto-create turn on orphaned content event', () {
      final controller = ChatSessionController();

      // Send content without turn_start
      controller.testOnWsMessage('{"message_id":"msg-1","type":"content_update","content":"Hello"}');

      expect(controller.turns.length, 1);
      expect(controller.turns.first.finalContent, 'Hello');
    });

    test('should handle tool call failure', () {
      final controller = ChatSessionController();

      controller.testOnWsMessage('{"message_id":"msg-1","type":"turn_start","role":"assistant"}');
      controller.testOnWsMessage('{"message_id":"msg-1","type":"tool_call_start","step_id":"step-1","tool_name":"fast_focus","args":{}}');
      controller.testOnWsMessage('{"message_id":"msg-1","type":"tool_call_end","step_id":"step-1","duration_ms":500,"result":"连接失败","success":false}');

      expect(controller.turns.first.thoughtSteps[0].status.toString(), contains('error'));
      expect(controller.turns.first.thoughtSteps[0].toolResult, '连接失败');
    });

    test('should ignore malformed messages', () {
      final controller = ChatSessionController();

      // Invalid JSON
      controller.testOnWsMessage('not json');

      // Missing fields
      controller.testOnWsMessage('{"type":"turn_start"}');
      controller.testOnWsMessage('{"message_id":"msg-1"}');

      expect(controller.turns.length, 0);
    });

    test('should format messages for copy', () {
      final controller = ChatSessionController();

      controller.testOnWsMessage('{"message_id":"user-1","type":"turn_start","role":"user"}');
      controller.testOnWsMessage('{"message_id":"user-1","type":"content_update","content":"用户消息"}');
      controller.testOnWsMessage('{"message_id":"user-1","type":"turn_end"}');
      controller.testOnWsMessage('{"message_id":"ast-1","type":"turn_start","role":"assistant"}');
      controller.testOnWsMessage('{"message_id":"ast-1","type":"thought_update","content":"思考"}');
      controller.testOnWsMessage('{"message_id":"ast-1","type":"content_update","content":"回复"}');
      controller.testOnWsMessage('{"message_id":"ast-1","type":"turn_end"}');

      final formatted = controller.formatMessagesForCopy();

      expect(formatted, contains('[用户] 用户消息'));
      expect(formatted, contains('[助手] 回复'));
      expect(formatted, contains('[思考过程]'));
      expect(formatted, contains('- 思考'));
    });
  });
}
