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

    test('appends thought deltas into one thought step', () {
      final turn = ChatTurn(messageId: 'm-thought');

      turn.appendThoughtDelta('正在');
      turn.appendThoughtDelta('分析');

      expect(turn.thoughtSteps.length, 1);
      expect(turn.thoughtSteps.single.type, StepType.thought);
      expect(turn.thoughtSteps.single.text, '正在分析');
    });

    test('thought update replaces accumulated deltas', () {
      final turn = ChatTurn(messageId: 'm-thought-final');

      turn.appendThoughtDelta('正在分');
      turn.replaceThoughtContent('正在分析完整上下文');

      expect(turn.thoughtSteps.length, 1);
      expect(turn.thoughtSteps.single.text, '正在分析完整上下文');
    });

    test('thought deltas do not append to snapshot thought steps', () {
      final turn = ChatTurn(messageId: 'm-thought-snapshot');

      turn.appendThoughtDelta('正在分析');
      turn.addThoughtStep('📊 工具执行摘要');
      turn.appendThoughtDelta('下一段');
      turn.replaceThoughtContent('完整思考');

      expect(turn.thoughtSteps.length, 2);
      expect(turn.thoughtSteps[0].text, '完整思考');
      expect(turn.thoughtSteps[1].text, '📊 工具执行摘要');
    });

    test('standalone thought updates append instead of replacing earlier thoughts', () {
      final turn = ChatTurn(messageId: 'm-multi-thought');

      turn.replaceThoughtContent('第一段思考');
      turn.replaceThoughtContent('第二段思考');

      expect(turn.thoughtSteps.length, 2);
      expect(turn.thoughtSteps[0].text, '第一段思考');
      expect(turn.thoughtSteps[1].text, '第二段思考');
    });

    test('tool call finalizes streaming thought so each LLM round keeps its own step', () {
      final turn = ChatTurn(messageId: 'm-rounds');

      turn.appendThoughtDelta('第一轮推理');
      turn.startToolCall(toolName: 't1', stepId: 's1');
      turn.endToolCall(status: ToolStatus.success, stepId: 's1');
      turn.appendThoughtDelta('第二轮');
      turn.replaceThoughtContent('第二轮定稿');

      expect(turn.thoughtSteps.length, 3);
      expect(turn.thoughtSteps[0].text, '第一轮推理');
      expect(turn.thoughtSteps[0].isStreamingThought, isFalse);
      expect(turn.thoughtSteps[1].toolName, 't1');
      expect(turn.thoughtSteps[2].text, '第二轮定稿');
    });

    test('parallel tool ends match by step_id not completion order', () {
      final turn = ChatTurn(messageId: 'm-parallel');

      turn.startToolCall(toolName: 'tool_a', stepId: 'step-a');
      turn.startToolCall(toolName: 'tool_b', stepId: 'step-b');

      turn.endToolCall(
        status: ToolStatus.success,
        resultText: 'result-b',
        stepId: 'step-b',
      );
      turn.endToolCall(
        status: ToolStatus.success,
        resultText: 'result-a',
        stepId: 'step-a',
      );

      expect(turn.steps.length, 2);
      expect(turn.steps[0].toolName, 'tool_a');
      expect(turn.steps[0].resultText, 'result-a');
      expect(turn.steps[1].toolName, 'tool_b');
      expect(turn.steps[1].resultText, 'result-b');
    });
  });
}
