import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Markdown 内容渲染组件。
///
/// 功能：
/// - 渲染 Markdown 格式文本
/// - 支持图像显示（包括 base64 图像）
/// - 支持代码块语法高亮
/// - 支持表格、列表等标准 Markdown 语法
/// - 提供复制原始文本功能
class MarkdownContentView extends StatefulWidget {
  const MarkdownContentView({
    super.key,
    required this.markdown,
    this.textColor,
    this.onCopy,
  });

  /// Markdown 格式的文本内容
  final String markdown;

  /// 文本颜色（可选）
  final Color? textColor;

  /// 复制回调（可选）
  final VoidCallback? onCopy;

  @override
  State<MarkdownContentView> createState() => _MarkdownContentViewState();
}

class _MarkdownContentViewState extends State<MarkdownContentView> {
  bool _copied = false;

  Future<void> _handleCopy() async {
    widget.onCopy?.call();
    if (widget.markdown.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: widget.markdown));
    if (!mounted) {
      return;
    }
    setState(() => _copied = true);
    // 1.5秒后重置复制状态
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = TextStyle(
      color: widget.textColor ?? theme.colorScheme.onSurface,
      fontSize: 14,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部栏：标题 + 复制按钮
        if (widget.onCopy != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                tooltip: _copied ? '已复制' : '复制文本',
                iconSize: 14,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                constraints: const BoxConstraints(),
                onPressed: _handleCopy,
                icon: Icon(
                  _copied ? Icons.check : Icons.copy,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 14,
                ),
              ),
            ],
          ),
        // Markdown 内容
        MarkdownBody(
          selectable: true,
          data: widget.markdown,
          styleSheet: MarkdownStyleSheet(
            // 基础文本样式
            p: textStyle,
            // 标题样式
            h1: textStyle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            h2: textStyle.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            h3: textStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            h4: textStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            h5: textStyle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            h6: textStyle.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            // 列表样式
            listBullet: textStyle.copyWith(
              fontSize: 14,
            ),
            // 代码块样式
            code: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: theme.colorScheme.onSurface,
            ),
            codeblockDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            codeblockPadding: const EdgeInsets.all(12),
            blockSpacing: 8,
            // 引用块样式
            blockquote: textStyle.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 3,
                ),
              ),
            ),
            blockquotePadding: const EdgeInsets.only(left: 12),
            // 表格样式
            tableHead: textStyle.copyWith(
              fontWeight: FontWeight.bold,
            ),
            tableBody: textStyle,
            tableBorder: TableBorder.all(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
            tableColumnWidth: const FlexColumnWidth(),
            // 分隔线样式
            horizontalRuleDecoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            // 链接样式
            a: TextStyle(
              color: theme.colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
            // 强调样式
            strong: textStyle.copyWith(
              fontWeight: FontWeight.bold,
            ),
            em: textStyle.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
          // 自定义图像构建器
          imageBuilder: (uri, title, alt) {
            return _buildImage(uri, alt) ?? const SizedBox.shrink();
          },
          // 自定义复选框构建器
          checkboxBuilder: (bool checked) {
            return Icon(
              checked ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: widget.textColor ?? theme.colorScheme.onSurface,
            );
          },
        ),
      ],
    );
  }

  /// 构建图像 Widget
  Widget? _buildImage(Uri? uri, String? alt) {
    if (uri == null) {
      return null;
    }

    Widget? imageWidget;

    // 处理 base64 图像
    if (uri.scheme == 'data' && uri.path.contains('image')) {
      try {
        // 解析 data URL
        final String dataUrl = uri.toString();
        final String base64String = dataUrl.split(',').last;
        final Uint8List bytes = base64Decode(base64String);

        imageWidget = Image.memory(
          bytes,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                alt ?? '无法加载图像',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            );
          },
        );
      } catch (e) {
        imageWidget = Container(
          padding: const EdgeInsets.all(8),
          child: Text(
            '图像数据解析失败',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 12,
            ),
          ),
        );
      }
    }
    // 处理网络图像
    else if (uri.scheme == 'http' || uri.scheme == 'https') {
      imageWidget = Image.network(
        uri.toString(),
        errorBuilder: (context, error, stackTrace) {
          return Container(
            padding: const EdgeInsets.all(8),
            child: Text(
              alt ?? '无法加载图像',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );
    }
    // 处理本地图像（assets）
    else if (uri.scheme == 'asset') {
      imageWidget = Image.asset(
        uri.path,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            padding: const EdgeInsets.all(8),
            child: Text(
              alt ?? '无法加载图像',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          );
        },
      );
    }

    if (imageWidget == null) {
      return null;
    }

    // 包装图像以支持交互式查看
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: imageWidget!,
      ),
    );
  }
}
