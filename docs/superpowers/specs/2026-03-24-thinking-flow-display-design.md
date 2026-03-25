# Thinking Flow Display Design

**Date:** 2026-03-24
**Status:** Design Approved
**Related Files:** `lib/ui/chat/*.dart`

## Overview

Redesign the chat interface to display AI thinking flow in a compact, interactive manner similar to modern web-based LLM interfaces. The thinking flow (tool calls, results, errors) should be collapsible with a live preview, animated activity indicator, and easy copy functionality.

## Requirements

### Functional Requirements
1. **Thinking Flow Grouping**: All intermediate messages (toolCall, toolResult, error, status) are grouped into a single "thinking block"
2. **Collapsed Preview**: Shows 4-5 lines of preview text when collapsed
3. **Expansion**: Click to expand and view full thinking details
4. **Activity Animation**: Shimmer border animation shows when thinking is active
5. **Separate Response**: Final assistant response displayed in its own bubble
6. **Copy Functionality**: All message bubbles have copy icon on right edge
7. **Auto-Collapse**: Thinking block automatically collapses after completion

### Non-Functional Requirements
- Follow existing Flutter project patterns and naming conventions
- Maintain backward compatibility with existing message format
- Minimal performance impact from animations
- Clean separation of concerns between data and UI layers

## Architecture

### Approach: Group Messages in Session Controller

The thinking flow grouping logic lives in the controller layer, keeping UI components simple and focused on rendering.

### Data Models

#### New Model: `ThinkingBlock`

```dart
class ThinkingBlock {
  final List<ChatMsg> messages;
  final DateTime startTime;
  bool isExpanded;
  bool isActive;

  ThinkingBlock({
    required this.messages,
    required this.startTime,
    this.isExpanded = false,
    this.isActive = true,
  });
}
```

#### New Union Type: `ChatDisplayItem`

```dart
sealed class ChatDisplayItem {}
class MessageItem extends ChatDisplayItem {
  final ChatMsg message;
  MessageItem(this.message);
}
class ThinkingItem extends ChatDisplayItem {
  final ThinkingBlock block;
  ThinkingItem(this.block);
}
```

#### Existing Model: `ChatMsg`

No changes - maintains backward compatibility with existing protocol handling.

### Controller Changes: `ChatSessionController`

**New Internal State:**
- `_displayItems`: `List<ChatDisplayItem>` - grouped items for UI consumption
- `_currentBlock`: `ThinkingBlock?` - active thinking block being built
- Maintains `_messages` for `formatMessagesForCopy()` compatibility

**New Public Methods:**

```dart
// Exposes grouped display items
List<ChatDisplayItem> get displayItems => List.unmodifiable(_displayItems);

// Toggle thinking block expansion
void toggleThinkingBlock(int index);

// Generate 4-5 line preview for collapsed state
String _formatBlockPreview(ThinkingBlock block);
```

**Grouping Logic:**

1. User sends message → create empty thinking block
2. Intermediate messages arrive → append to current block
3. Assistant response arrives → close block, add as separate display item
4. Block's `isActive` tracks whether agent is still busy

**Protocol Handler Update:**

Modified `ChatProtocolMapper.applyEvent()` to signal thinking lifecycle:
- `agent_start` → mark thinking as active
- `done` → mark thinking as inactive, trigger collapse

### UI Components

#### New Widget: `ThinkingFlowWidget`

```dart
class ThinkingFlowWidget extends StatelessWidget {
  final ThinkingBlock block;
  final ValueChanged<bool> onToggleExpansion;
  final VoidCallback onCopy;

  // Renders:
  // - Shimmer border when block.isActive
  // - Collapsed preview (4-5 lines) or expanded content
  // - Tap gesture to toggle
  // - Copy icon on right edge
}
```

**Component Structure:**
```
ThinkingFlowWidget
├── Container (shimmer border when active)
│   ├── Column
│   │   ├── Header (icon + title + timestamp)
│   │   ├── PreviewContainer (collapsed)
│   │   └── ExpandedContent (expanded)
│   └── CopyButton (right edge)
```

#### New Widget: `MessageBubble`

```dart
class MessageBubble extends StatelessWidget {
  final ChatMsg message;
  final VoidCallback onCopy;

  // Reusable wrapper for user/assistant messages
  // - SelectableText for content
  // - Copy icon with tooltip feedback
}
```

#### Modified: `ChatPanel`

**Updated Parameters:**
- `displayItems` replaces `messages`
- `onCopyMessage` callback added

**Updated Methods:**
- `_buildDisplayItem` - dispatches to appropriate widget based on item type
- `_buildThinkingFlow` - renders `ThinkingFlowWidget`
- `_buildMessage` - renders `MessageBubble` for single messages

### Animation Design

#### Shimmer Border Animation

**Implementation:**
```dart
AnimationController _shimmerController = AnimationController(
  duration: Duration(seconds: 2),
  vsqync: this,
);

LinearGradient _buildShimmerGradient(ColorScheme cs) {
  return LinearGradient(
    colors: [
      Colors.transparent,
      cs.primary.withOpacity(0.6),
      Colors.transparent,
    ],
    stops: [0.0, _shimmerController.value, 1.0],
  );
}
```

**Behavior:**
- Only animates when `ThinkingBlock.isActive == true`
- Stops animation when thinking completes
- Uses `RepaintBoundary` to limit redraw scope

#### Expansion Animation (Optional)

```dart
AnimatedContainer(
  duration: Duration(milliseconds: 200),
  curve: Curves.easeInOut,
  // ... content
)
```

### Copy Functionality

**Implementation:**

```dart
// In MessageBubble and ThinkingFlowWidget
void _handleCopy() async {
  await Clipboard.setData(ClipboardData(text: _content));
  setState(() => _showCopiedFeedback = true);
  Timer(Duration(milliseconds: 1500), () {
    setState(() => _showCopiedFeedback = false);
  });
}
```

**Copy Button Widget:**

```dart
Tooltip(
  message: _showCopiedFeedback ? '已复制!' : '复制',
  waitDuration: Duration.zero,
  child: IconButton(
    icon: Icon(Icons.copy, size: 16),
    onPressed: _handleCopy,
  ),
)
```

**Copy Behavior:**
- **User/Assistant bubbles**: Copy full message text
- **Thinking flow expanded**: Copy all intermediate messages
- **Thinking flow collapsed**: Copy preview text only

**Visual Feedback:**
- Tooltip shows "已复制!" for 1.5 seconds after successful copy
- Button semi-transparent by default, full opacity on hover

## Data Flow

```
WebSocket Message
    ↓
ChatProtocolMapper.applyEvent()
    ↓
ChatSessionController._onWsMessage()
    ↓
_groupMessagesIntoDisplayItems()
    ↓
_displayItems updated
    ↓
notifyListeners()
    ↓
ChatPanel rebuilds with new displayItems
    ↓
ThinkingFlowWidget / MessageBubble render
```

## Error Handling

1. **Malformed messages**: Continue to render, log error, don't crash UI
2. **Copy failure**: Silent failure, no error shown to user
3. **Animation errors**: Fallback to static border if animation fails
4. **Empty thinking blocks**: Don't render blocks with no messages

## Testing Strategy

### Unit Tests
1. `ChatSessionController` grouping logic
2. `ThinkingBlock` state management
3. `_formatBlockPreview` text generation
4. Copy functionality for different message types

### Widget Tests
1. `ThinkingFlowWidget` rendering in collapsed/expanded states
2. Shimmer animation appears when `isActive == true`
3. Copy button triggers callback correctly
4. Expansion toggle updates state

### Integration Tests
1. Full user flow: send message → thinking → response
2. Multiple consecutive thinking blocks
3. Copy from different bubble types
4. Expansion state persistence during conversation

## Implementation Phases

### Phase 1: Data Layer
- [ ] Create `ThinkingBlock` model
- [ ] Create `ChatDisplayItem` union type
- [ ] Update `ChatSessionController` with grouping logic
- [ ] Add unit tests for controller

### Phase 2: UI Components
- [ ] Implement `ThinkingFlowWidget` without animations
- [ ] Implement `MessageBubble` with copy functionality
- [ ] Update `ChatPanel` to use new display items
- [ ] Add widget tests

### Phase 3: Animations
- [ ] Add shimmer border animation
- [ ] Add expansion animation
- [ ] Optimize with `RepaintBoundary`

### Phase 4: Polish
- [ ] Refine preview text formatting
- [ ] Add tooltip feedback
- [ ] Test performance
- [ ] Fix any remaining issues

## Open Questions

None - design is complete and approved.

## Dependencies

- `flutter/material.dart` - existing
- No new external packages required

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Animation performance issues | Medium | Use `RepaintBoundary`, monitor in devtools |
| Complex grouping logic bugs | High | Comprehensive unit tests, gradual rollout |
| Copy functionality edge cases | Low | Silent failure, graceful degradation |
| Backward compatibility break | Medium | Keep `ChatMsg` unchanged, add new layer on top |

## Success Criteria

- ✅ Thinking flow grouped into collapsible blocks
- ✅ Shimmer animation shows during active thinking
- ✅ Click to expand/collapse works smoothly
- ✅ Copy icon appears on all message types
- ✅ Copy feedback tooltip displays correctly
- ✅ Auto-collapse occurs after thinking completes
- ✅ No performance degradation in devtools
- ✅ All tests passing
