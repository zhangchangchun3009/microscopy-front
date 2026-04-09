import 'package:flutter/foundation.dart';

/// turn 气泡角色。
enum TurnRole {
  /// 用户消息。
  user,

  /// 助手消息。
  assistant,
}

/// 渲染文档模型。
class RenderedDocument {
  /// 创建渲染文档。
  const RenderedDocument({
    required this.markdown,
    required this.images,
    required this.metadata,
    this.ttsText,
  });

  /// Markdown 内容。
  final String markdown;

  /// 图片引用列表。
  final List<ImageReference> images;

  /// 文档元数据。
  final DocumentMetadata metadata;

  /// TTS 文本（可选）。
  final String? ttsText;

  /// 从 JSON 创建渲染文档。
  factory RenderedDocument.fromJson(Map<String, dynamic> json) {
    return RenderedDocument(
      markdown: json['markdown'] as String? ?? '',
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => ImageReference.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      metadata: DocumentMetadata.fromJson(json['metadata'] as Map<String, dynamic>? ?? {}),
      ttsText: json['tts_text'] as String?,
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() {
    return {
      'markdown': markdown,
      'images': images.map((e) => e.toJson()).toList(),
      'metadata': metadata.toJson(),
      if (ttsText != null) 'tts_text': ttsText,
    };
  }
}

/// 图片引用模型。
class ImageReference {
  /// 创建图片引用。
  const ImageReference({
    required this.artifactId,
    required this.url,
    this.caption,
    required this.layout,
  });

  /// Artifact ID。
  final String artifactId;

  /// 图片 URL。
  final String url;

  /// 图片说明（可选）。
  final String? caption;

  /// 布局类型。
  final ImageLayout layout;

  /// 从 JSON 创建图片引用。
  factory ImageReference.fromJson(Map<String, dynamic> json) {
    return ImageReference(
      artifactId: json['artifact_id'] as String,
      url: json['url'] as String,
      caption: json['caption'] as String?,
      layout: ImageLayout.fromString(json['layout'] as String? ?? 'single'),
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() {
    return {
      'artifact_id': artifactId,
      'url': url,
      if (caption != null) 'caption': caption,
      'layout': layout.toString(),
    };
  }
}

/// 图片布局类型。
enum ImageLayout {
  single,
  grid,
  thumbnailList,
  comparison;

  /// 从字符串创建布局类型。
  static ImageLayout fromString(String value) {
    switch (value.toLowerCase()) {
      case 'single':
        return ImageLayout.single;
      case 'grid':
        return ImageLayout.grid;
      case 'thumbnaillist':
        return ImageLayout.thumbnailList;
      case 'comparison':
        return ImageLayout.comparison;
      default:
        return ImageLayout.single;
    }
  }

  @override
  String toString() {
    switch (this) {
      case ImageLayout.single:
        return 'single';
      case ImageLayout.grid:
        return 'grid';
      case ImageLayout.thumbnailList:
        return 'thumbnailList';
      case ImageLayout.comparison:
        return 'comparison';
    }
  }
}

/// 文档元数据。
class DocumentMetadata {
  /// 创建文档元数据。
  const DocumentMetadata({
    required this.title,
    required this.generatedAt,
    required this.durationMs,
    required this.operationType,
    required this.success,
  });

  /// 标题。
  final String title;

  /// 生成时间。
  final DateTime generatedAt;

  /// 耗时（毫秒）。
  final int durationMs;

  /// 操作类型。
  final String operationType;

  /// 是否成功。
  final bool success;

  /// 从 JSON 创建文档元数据。
  factory DocumentMetadata.fromJson(Map<String, dynamic> json) {
    return DocumentMetadata(
      title: json['title'] as String? ?? '',
      generatedAt: DateTime.tryParse(json['generated_at'] as String? ?? '') ?? DateTime.now(),
      durationMs: json['duration_ms'] as int? ?? 0,
      operationType: json['operation_type'] as String? ?? '',
      success: json['success'] as bool? ?? false,
    );
  }

  /// 转换为 JSON。
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'generated_at': generatedAt.toIso8601String(),
      'duration_ms': durationMs,
      'operation_type': operationType,
      'success': success,
    };
  }
}

/// turn 内步骤类型。
enum StepType {
  /// 思考过程的增量描述。
  thought,

  /// 工具调用步骤（开始/结束会归并为同一步）。
  toolCall,

  /// 最终回复内容增量。
  content,

  /// turn 完成标记。
  done,
}

/// 工具调用状态。
enum ToolStatus {
  /// 调用已开始，尚未结束。
  running,

  /// 调用成功完成。
  success,

  /// 调用失败。
  error,
}

/// 单个 turn 内的步骤模型。
class ThoughtStep {
  /// 创建步骤。
  ThoughtStep({
    required this.type,
    this.text,
    this.toolName,
    this.argsText,
    this.stepId,
    this.resultText,
    this.toolStatus,
    List<Uint8List>? previewImages,
    DateTime? timestamp,
  })  : previewImages = previewImages != null
            ? List<Uint8List>.from(previewImages)
            : <Uint8List>[],
        timestamp = timestamp ?? DateTime.now();

  /// 步骤类型。
  final StepType type;

  /// 步骤文本（思考文本或内容文本）。
  String? text;

  /// 工具名（仅 [StepType.toolCall] 使用）。
  final String? toolName;

  /// 工具参数文本（可选）。
  final String? argsText;

  /// 与服务端 `tool_call_start` / `tool_call_end` 的 `step_id` 对齐；并行工具时用于归因结果。
  final String? stepId;

  /// 工具结果文本（可选）。
  String? resultText;

  /// 工具状态（仅 [StepType.toolCall] 使用）。
  ToolStatus? toolStatus;

  /// 工具成功后附带的图像预览（如 `capture_image`），仅用于 UI，不参与模型上下文。
  final List<Uint8List> previewImages;

  /// 记录步骤时间。
  final DateTime timestamp;
}

/// 单个会话 turn 聚合模型（按 message_id 唯一）。
///
/// 该模型负责把 `thought/tool/content/done` 事件聚合为有序步骤。
class ChatTurn extends ChangeNotifier {
  /// 创建 turn。
  ChatTurn({
    required this.messageId,
    this.role = TurnRole.assistant,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 服务端 message_id。
  final String messageId;

  /// 当前 turn 对应的说话方（用户/助手）。
  final TurnRole role;

  /// turn 创建时间。
  final DateTime createdAt;

  final List<ThoughtStep> _steps = [];

  /// 渲染文档（由渲染子代理生成）。
  RenderedDocument? renderedDocument;

  /// 聚合后的步骤列表（只读）。
  List<ThoughtStep> get steps => List.unmodifiable(_steps);

  /// turn 是否结束。
  bool get isFinished => _steps.any((step) => step.type == StepType.done);

  /// 兼容 UI 命名：turn 是否已完成。
  bool get isComplete => isFinished;

  /// 思考与工具步骤（不包含内容/结束标记）。
  List<ThoughtStep> get thoughtSteps => List.unmodifiable(
    _steps.where((step) => step.type == StepType.thought || step.type == StepType.toolCall),
  );

  /// 聚合后的最终文本（取最后一个 content 步骤）。
  String get finalContent {
    for (final step in _steps.reversed) {
      if (step.type == StepType.content) {
        return step.text ?? '';
      }
    }
    return '';
  }

  /// 过滤后的最终文本：移除 LLM 可能输出的 `![](data:image/...;base64,...)`
  /// 这种内联 base64 图片占位，避免正文里出现大段 base64 信息。
  String get filteredFinalContent => _stripInlineDataImageBase64(finalContent);

  /// 移除所有 `![](data:image/...;base64,...)` 的 Markdown 内联图片占位。
  ///
  /// 说明：
  /// - 仅针对 `data:image/*;base64,` 形式；
  /// - 不影响你在工具预览区外渲染的图片（那是由 `previewImages` 解码出来的）。
  /// 移除所有 `![](data:image/...;base64,...)` 的 Markdown 内联图片占位。
  ///
  /// 该方法同时用于正文展示与思考过程/纯文本转写中的过滤。
  static String stripInlineDataImageBase64(String input) {
    if (input.isEmpty) {
      return input;
    }
    // Match entire Markdown image: ![alt](data:image/<type>;base64,<payload>)
    final mdDataImagePattern = RegExp(
      r'!\[[^\]]*\]\(data:image\/[^)]*?base64,[^)]*?\)',
      multiLine: true,
    );
    return input.replaceAll(mdDataImagePattern, '').trim();
  }

  // Backward compatible alias for any internal call sites.
  static String _stripInlineDataImageBase64(String input) =>
      stripInlineDataImageBase64(input);

  /// UI 折叠状态：是否展开思考步骤。
  bool isThinkingExpanded = false;

  /// 追加思考步骤。
  void addThoughtStep(String text) {
    _steps.add(ThoughtStep(type: StepType.thought, text: text));
    notifyListeners();
  }

  /// 开始一个工具调用步骤。
  void startToolCall({String? toolName, String? argsText, String? stepId}) {
    _steps.add(
      ThoughtStep(
        type: StepType.toolCall,
        toolName: toolName,
        argsText: argsText,
        stepId: stepId,
        toolStatus: ToolStatus.running,
      ),
    );
    notifyListeners();
  }

  /// 结束工具调用步骤。
  ///
  /// [stepId] 与事件 `tool_call_end.step_id` 一致时应传入，以便并行工具时把结果归因到正确步骤。
  /// 未传时保持旧行为：结束「最后一个仍为 running 的工具步骤」（仅适合串行或单工具）。
  ///
  /// 若不存在可匹配的步骤，会创建一个匿名工具步骤并直接结束。
  void endToolCall({
    required ToolStatus status,
    String? resultText,
    List<Uint8List>? previewImages,
    String? stepId,
  }) {
    ThoughtStep? active;
    final sid = stepId?.trim();
    if (sid != null && sid.isNotEmpty) {
      for (final step in _steps) {
        if (step.type == StepType.toolCall &&
            step.toolStatus == ToolStatus.running &&
            step.stepId == sid) {
          active = step;
          break;
        }
      }
    }
    if (active == null) {
      for (final step in _steps.reversed) {
        if (step.type == StepType.toolCall && step.toolStatus == ToolStatus.running) {
          active = step;
          break;
        }
      }
    }

    if (active == null) {
      active = ThoughtStep(
        type: StepType.toolCall,
        toolStatus: status,
        resultText: resultText,
        previewImages: previewImages,
      );
      _steps.add(active);
    } else {
      active.toolStatus = status;
      active.resultText = resultText;
      if (previewImages != null && previewImages.isNotEmpty) {
        active.previewImages
          ..clear()
          ..addAll(previewImages);
      }
    }
    notifyListeners();
  }

  /// 聚合内容增量到单个 content 步骤。
  void updateContent(String delta) {
    ThoughtStep? contentStep;
    for (final step in _steps.reversed) {
      if (step.type == StepType.content) {
        contentStep = step;
        break;
      }
    }
    if (contentStep == null) {
      _steps.add(ThoughtStep(type: StepType.content, text: delta));
    } else {
      contentStep.text = '${contentStep.text ?? ''}$delta';
    }
    notifyListeners();
  }

  /// 标记 turn 结束。
  void finish() {
    if (!isFinished) {
      _steps.add(ThoughtStep(type: StepType.done));
      notifyListeners();
    }
  }

  /// 设置渲染文档（由渲染子代理生成）。
  void setRenderedDocument(RenderedDocument document) {
    renderedDocument = document;
    notifyListeners();
  }
}
