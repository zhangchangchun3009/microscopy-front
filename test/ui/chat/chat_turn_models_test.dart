import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_turn_models.dart';

void main() {
  group('ChatTurn', () {
    test('should aggregate thought updates', () {
      final turn = ChatTurn(id: 'test-1', role: 'assistant');
      turn.addThoughtText('思考1');
      // Add a tool call to break consecutive text
      turn.startToolCall('step-1', 'tool1', {});
      turn.addThoughtText('思考2');

      expect(turn.thoughtSteps.length, 3);
      expect(turn.thoughtSteps[0].content, '思考1');
      expect(turn.thoughtSteps[1].toolName, 'tool1');
      expect(turn.thoughtSteps[2].content, '思考2');
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

    test('should handle tool call error', () {
      final turn = ChatTurn(id: 'test-3b', role: 'assistant');
      turn.startToolCall('step-1', 'fast_focus', {});

      turn.endToolCallWithError('step-1', 500, '连接失败');

      expect(turn.thoughtSteps[0].status, ToolStatus.error);
      expect(turn.thoughtSteps[0].durationMs, 500);
      expect(turn.thoughtSteps[0].toolResult, '连接失败');
      expect(turn.thoughtSteps[0].content, contains('失败'));
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

    test('should toggle expanded state', () {
      final turn = ChatTurn(id: 'test-6', role: 'assistant');
      expect(turn.isExpanded, false);

      turn.toggleExpanded();
      expect(turn.isExpanded, true);

      turn.toggleExpanded();
      expect(turn.isExpanded, false);
    });

    test('should create user turn', () {
      final turn = ChatTurn(id: 'user-1', role: 'user');
      expect(turn.role, 'user');
      expect(turn.id, 'user-1');
      expect(turn.isComplete, false);
    });

    test('should create assistant turn with custom start time', () {
      final time = DateTime(2026, 3, 24, 12, 30);
      final turn = ChatTurn(id: 'ast-1', role: 'assistant', startTime: time);
      expect(turn.startTime, time);
    });
  });

  group('ThoughtStep', () {
    test('should create text step', () {
      final step = ThoughtStep(type: StepType.text, content: '思考内容');
      expect(step.type, StepType.text);
      expect(step.content, '思考内容');
      expect(step.id, null);
    });

    test('should create tool step', () {
      final step = ThoughtStep(
        id: 'step-1',
        type: StepType.tool,
        toolName: 'microscope_control',
        status: ToolStatus.running,
      );
      expect(step.type, StepType.tool);
      expect(step.id, 'step-1');
      expect(step.toolName, 'microscope_control');
      expect(step.status, ToolStatus.running);
    });
  });
}
