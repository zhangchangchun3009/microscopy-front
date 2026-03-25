import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_turn_models.dart';

void main() {
  group('ChatTurn', () {
    test('aggregates thought, tool and content steps in order', () {
      final turn = ChatTurn(messageId: 'm1');

      turn.addThoughtStep('思考中...');
      turn.startToolCall(toolName: 'search', argsText: '{"q":"abc"}');
      turn.endToolCall(status: ToolStatus.success, resultText: 'ok');
      turn.updateContent('你好');
      turn.updateContent('，世界');
      turn.finish();

      expect(turn.steps.length, 4);
      expect(turn.steps[0].type, StepType.thought);
      expect(turn.steps[1].type, StepType.toolCall);
      expect(turn.steps[1].toolName, 'search');
      expect(turn.steps[1].toolStatus, ToolStatus.success);
      expect(turn.steps[2].type, StepType.content);
      expect(turn.steps[2].text, '你好，世界');
      expect(turn.steps[3].type, StepType.done);
      expect(turn.isFinished, isTrue);
    });

    test('keeps single active tool step and marks failure', () {
      final turn = ChatTurn(messageId: 'm2');
      turn.startToolCall(toolName: 'planner');
      turn.endToolCall(status: ToolStatus.error, resultText: 'boom');

      expect(turn.steps.length, 1);
      expect(turn.steps.single.type, StepType.toolCall);
      expect(turn.steps.single.toolStatus, ToolStatus.error);
      expect(turn.steps.single.resultText, 'boom');
    });
  });
}
