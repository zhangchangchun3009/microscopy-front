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
  String? toolResult;
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
  }) : startTime = startTime ?? DateTime.now();

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
