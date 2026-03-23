# 显微镜智能助手 UI 改进设计文档

**日期**: 2026-03-23
**状态**: 设计阶段
**范围**: microscopy-front Flutter macOS 应用

## 概述

优化显微镜代理应用的用户界面，提升用户体验和交互一致性。

## 目标

1. 将应用标题"显微镜代理"改为"显微镜智能助手"
2. 为对话消息添加角色标识和时间戳
3. 优化收起按钮位置，提升布局对称性
4. 添加拖动边框的视觉反馈

## 需求

### 1. 应用标题更新

- **位置**: AppBar 标题、应用 title
- **变更**: "显微镜代理" → "显微镜智能助手"

### 2. 消息头部标识

每条对话消息添加头部信息，显示在气泡外部左侧：

**助手消息**:
- 图标: `Icons.smart_toy` (机器人)
- 文字: "助手@03-23 14:30"
- 颜色: 灰色系

**用户消息**:
- 图标: `Icons.person` (人物)
- 文字: "我@03-23 14:30"
- 颜色: 主色系

**时间格式**: `MM-dd HH:mm` (如 "03-23 14:30")

### 3. 收起按钮位置优化

- **当前**: 按钮在对话框顶部左侧
- **优化**: 按钮移至对话框左侧边框垂直居中
- **对称性**: 展开和折叠状态的按钮位置对称

### 4. 拖动边框视觉反馈

- **当前**: 拖动左边框无鼠标光标变化
- **优化**: 鼠标悬停时显示 `SystemMouseCursors.resizeLeftRight` 光标
- **边框宽度**: 保持 8px

## 设计方案

### 组件: `_MessageHeader`

新增组件，负责渲染消息头部。

**参数**:
```dart
final MsgRole role
final DateTime time
final ColorScheme cs
```

**UI 结构**:
```
Row(
  children: [
    Icon(role == assistant ? Icons.smart_toy : Icons.person, size: 16),
    SizedBox(width: 6),
    Text(role == assistant ? "助手" : "我", fontSize: 12),
    SizedBox(width: 4),
    Text("@03-23 14:30", fontSize: 11, color: gray),
  ],
)
```

### 消息气泡修改

将 `_userBubble` 和 `_assistantBubble` 改为 Row 布局：

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    _MessageHeader(role: msg.role, time: msg.time, cs: cs),
    SizedBox(width: 8),
    Expanded(child: Container(...原气泡...)),
  ],
)
```

### 时间格式化工具

```dart
String _formatMessageTime(DateTime time) {
  return '${time.month.toString().padLeft(2, '0')}-'
         '${time.day.toString().padLeft(2, '0')} '
         '${time.hour.toString().padLeft(2, '0')}:'
         '${time.minute.toString().padLeft(2, '0')}';
}
```

### 布局交互优化

#### 收起按钮定位

使用 `Stack` + `Positioned` 将按钮中心对齐边框：

```dart
Expanded(
  child: Stack(
    clipBehavior: Clip.none,
    children: [
      widget.rightChatPane,
      Positioned(
        left: -8,  // 24px 按钮中心对齐 8px 边框
        top: 0,
        bottom: 0,
        child: Center(
          child: InkWell(
            onTap: () => _toggleChat(windowWidth),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Icon(Icons.chevron_right, size: 18),
            ),
          ),
        ),
      ),
    ],
  ),
)
```

#### 拖动光标反馈

```dart
MouseRegion(
  cursor: SystemMouseCursors.resizeLeftRight,
  child: GestureDetector(
    behavior: HitTestBehavior.opaque,
    onHorizontalDragUpdate: (details) => _onResizeDragUpdate(details, windowWidth),
    child: Container(
      width: _dragHandleWidth,
      color: Colors.transparent,
    ),
  ),
)
```

## 文件变更清单

### 修改文件

**lib/main.dart**
- 第 28 行: 应用 title
- 第 193 行: AppBar 标题

**lib/ui/chat/chat_panel.dart**
- 新增 `_formatMessageTime` 方法 (~5 行)
- 新增 `_MessageHeader` 组件 (~30 行)
- 修改 `_userBubble` 方法 (~10 行)
- 修改 `_assistantBubble` 方法 (~10 行)

**lib/ui/layout/right_chat_split_layout.dart**
- 拖动手柄添加 `MouseRegion` (~5 行)
- 重构展开状态布局 (~20 行)

### 无需修改

- `lib/ui/chat/chat_models.dart` - 已有 `time` 字段
- `lib/ui/chat/chat_session_controller.dart` - 逻辑不变
- `lib/ui/layout/chat_panel_width_model.dart` - 模型不变

## 测试要点

### 功能测试

- [ ] App 标题显示为"显微镜智能助手"
- [ ] 助手消息显示机器人图标 + "助手@时间"
- [ ] 用户消息显示人物图标 + "我@时间"
- [ ] 时间格式正确 (MM-dd HH:mm)
- [ ] 收起按钮在对话框左侧边框垂直居中
- [ ] 鼠标悬停左边框显示左右箭头
- [ ] 拖动边框可调整宽度
- [ ] 点击收起按钮折叠/展开对话框

### 视觉测试

- [ ] 消息头部与气泡对齐正确
- [ ] 长消息不导致头部换行
- [ ] 收起按钮不遮挡聊天内容
- [ ] 拖动时光标响应流畅

## 未来扩展

当前设计支持未来功能扩展：

1. **自定义头像**: `_MessageHeader` 可接受 `Image` widget 替代图标
2. **显示名称**: 可添加 `userName` 参数显示个性化名称
3. **点击头像**: 可为头像添加 `onTap` 回调显示用户详情

## 技术约束

- Flutter macOS 平台
- Material 3 设计系统
- 保持现有消息数据模型不变
- 不破坏现有拖动和折叠功能
