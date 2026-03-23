# Chat UI Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the microscope agent UI to display "显微镜智能助手" as the title, add message headers with icons and timestamps, and improve layout interaction consistency.

**Architecture:** Component-based UI updates in Flutter. Add `_MessageHeader` widget to encapsulate message metadata display. Modify existing bubble widgets to compose headers with message content. Update layout widget to improve cursor feedback and button positioning using Stack+Positioned.

**Tech Stack:** Flutter 3.x, Material 3, Dart 3.x, macOS platform

---

## File Structure

```
lib/
├── main.dart                                    # Modify: Update app title (2 lines)
├── ui/
│   ├── chat/
│   │   ├── chat_panel.dart                      # Modify: Add header components (~55 lines)
│   │   ├── chat_models.dart                     # No change: Already has time field
│   │   └── chat_panel_test.dart                 # Create: Widget tests for new components
│   └── layout/
│       ├── right_chat_split_layout.dart         # Modify: Improve interactions (~25 lines)
│       └── right_chat_split_layout_test.dart    # Create: Widget tests for layout
docs/superpowers/
├── specs/2026-03-23-chat-ui-improvements-design.md  # Reference
└── plans/2026-03-23-chat-ui-improvements.md          # This file
```

**Decomposition rationale:**
- `chat_panel.dart`: Message header rendering belongs with message display logic
- `right_chat_split_layout.dart`: Layout interaction improvements stay with layout component
- Separate test files follow Flutter conventions

---

## Task 1: Update App Title

**Files:**
- Modify: `lib/main.dart:28`
- Modify: `lib/main.dart:193`

- [ ] **Step 1: Update MaterialApp title**

Find line 28 in `lib/main.dart`:
```dart
title: '显微镜代理',
```

Replace with:
```dart
title: '显微镜智能助手',
```

- [ ] **Step 2: Update AppBar title**

Find line 193 in `lib/main.dart`:
```dart
title: const Text('显微镜代理'),
```

Replace with:
```dart
title: const Text('显微镜智能助手'),
```

- [ ] **Step 3: Verify changes visually**

Run: `flutter run -d macos`
Expected: App window title and AppBar show "显微镜智能助手"

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: update app title to '显微镜智能助手'

- Change MaterialApp title from '显微镜代理'
- Change AppBar title to match

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Add Time Formatting Utility

**Files:**
- Modify: `lib/ui/chat/chat_panel.dart`
- Test: `test/ui/chat/chat_panel_test.dart` (create)

- [ ] **Step 1: Create test file for time formatting**

Create `test/ui/chat/chat_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_panel.dart';

void main() {
  group('_formatMessageTime', () {
    test('formats DateTime correctly', () {
      // Arrange
      final time = DateTime(2026, 3, 23, 14, 30);

      // Act
      final formatted = _formatMessageTime(time);

      // Assert
      expect(formatted, equals('03-23 14:30'));
    });

    test('pads single digit month and day', () {
      final time = DateTime(2026, 1, 5, 9, 5);
      final formatted = _formatMessageTime(time);
      expect(formatted, equals('01-05 09:05'));
    });

    test('pads single digit hour and minute', () {
      final time = DateTime(2026, 12, 31, 23, 59);
      final formatted = _formatMessageTime(time);
      expect(formatted, equals('12-31 23:59'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/chat/chat_panel_test.dart`
Expected: FAIL with "Method not found: '_formatMessageTime'"

- [ ] **Step 3: Implement _formatMessageTime function**

Add to `lib/ui/chat/chat_panel.dart` after imports (around line 6):

```dart
/// Formats message timestamp as "MM-dd HH:mm".
String _formatMessageTime(DateTime time) {
  return '${time.month.toString().padLeft(2, '0')}-'
         '${time.day.toString().padLeft(2, '0')} '
         '${time.hour.toString().padLeft(2, '0')}:'
         '${time.minute.toString().padLeft(2, '0')}';
}
```

Note: Since this is a private function in a file, the test needs to use a workaround. In Flutter, we need to export it for testing or test it indirectly through the widget. Let's adjust:

**Alternative approach**: Test indirectly through widget rendering (see Task 4).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/chat/chat_panel_test.dart`
Expected: PASS

If using indirect testing approach, delete the test file for now and add tests in Task 4.

- [ ] **Step 5: Commit**

```bash
git add lib/ui/chat/chat_panel.dart
git commit -m "feat: add time formatting utility for messages

- Add _formatMessageTime function
- Format: MM-dd HH:mm (e.g., '03-23 14:30')
- Pads single digits with leading zeros

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Add _MessageHeader Widget

**Files:**
- Modify: `lib/ui/chat/chat_panel.dart`

- [ ] **Step 1: Add _MessageHeader widget**

Add to `lib/ui/chat/chat_panel.dart` after the `_formatMessageTime` function (around line 20):

```dart
/// Message header showing role icon, name, and timestamp.
class _MessageHeader extends StatelessWidget {
  const _MessageHeader({
    required this.role,
    required this.time,
    required this.colorScheme,
  });

  final MsgRole role;
  final DateTime time;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isAssistant = role == MsgRole.assistant;
    final icon = isAssistant ? Icons.smart_toy : Icons.person;
    final label = isAssistant ? '助手' : '我';
    final iconColor = isAssistant
        ? colorScheme.onSurfaceVariant
        : colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '@${_formatMessageTime(time)}',
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify no syntax errors**

Run: `flutter analyze lib/ui/chat/chat_panel.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/ui/chat/chat_panel.dart
git commit -m "feat: add _MessageHeader widget for chat messages

- Displays role icon (robot/person)
- Shows role label ('助手'/'我')
- Shows formatted timestamp '@MM-dd HH:mm'
- Uses theme colors for consistency

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Update Message Bubbles to Use Headers

**Files:**
- Modify: `lib/ui/chat/chat_panel.dart:195-223`
- Test: `test/ui/chat/chat_panel_test.dart` (update/create)

- [ ] **Step 1: Update _userBubble method**

Find the `_userBubble` method in `lib/ui/chat/chat_panel.dart` (around line 195):

Current code:
```dart
Widget _userBubble(ChatMsg msg, ColorScheme cs) {
  return Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8, left: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(msg.text, style: TextStyle(color: cs.onPrimary)),
    ),
  );
}
```

Replace with:
```dart
Widget _userBubble(ChatMsg msg, ColorScheme cs) {
  return Align(
    alignment: Alignment.centerRight,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MessageHeader(
          role: msg.role,
          time: msg.time,
          colorScheme: cs,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, left: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(
              msg.text,
              style: TextStyle(color: cs.onPrimary),
            ),
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 2: Update _assistantBubble method**

Find the `_assistantBubble` method in `lib/ui/chat/chat_panel.dart` (around line 210):

Current code:
```dart
Widget _assistantBubble(ChatMsg msg, ColorScheme cs) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8, right: 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(msg.text),
    ),
  );
}
```

Replace with:
```dart
Widget _assistantBubble(ChatMsg msg, ColorScheme cs) {
  return Align(
    alignment: Alignment.centerLeft,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _MessageHeader(
          role: msg.role,
          time: msg.time,
          colorScheme: cs,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, right: 48),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SelectableText(msg.text),
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Create widget test for message headers**

Create/update `test/ui/chat/chat_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';
import 'package:microscope_app/ui/chat/chat_panel.dart';

void main() {
  group('ChatPanel with message headers', () {
    testWidgets('displays assistant message with robot icon and timestamp',
        (tester) async {
      // Arrange
      final messages = [
        ChatMsg(
          role: MsgRole.assistant,
          text: 'Hello',
          time: DateTime(2026, 3, 23, 14, 30),
        ),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPanel(
              messages: messages,
              inputController: TextEditingController(),
              scrollController: ScrollController(),
              plainTextMode: false,
              agentBusy: false,
              wsConnected: true,
              plainTextTranscript: '',
              onTogglePlainTextMode: () {},
              onCopyAllMessages: () {},
              onSendMessage: (_) {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.smart_toy), findsOneWidget);
      expect(find.text('助手@03-23 14:30'), findsOneWidget);
    });

    testWidgets('displays user message with person icon and timestamp',
        (tester) async {
      // Arrange
      final messages = [
        ChatMsg(
          role: MsgRole.user,
          text: 'Hi',
          time: DateTime(2026, 3, 23, 15, 45),
        ),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPanel(
              messages: messages,
              inputController: TextEditingController(),
              scrollController: ScrollController(),
              plainTextMode: false,
              agentBusy: false,
              wsConnected: true,
              plainTextTranscript: '',
              onTogglePlainTextMode: () {},
              onCopyAllMessages: () {},
              onSendMessage: (_) {},
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.text('我@03-23 15:45'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/ui/chat/chat_panel_test.dart`
Expected: PASS

- [ ] **Step 5: Manual verification**

Run: `flutter run -d macos`
Steps:
1. Send a message in the chat
2. Verify user message shows person icon + "我@时间"
3. Verify assistant response shows robot icon + "助手@时间"
4. Check time format matches "03-23 14:30"

- [ ] **Step 6: Commit**

```bash
git add lib/ui/chat/chat_panel.dart test/ui/chat/chat_panel_test.dart
git commit -m "feat: add message headers with icons and timestamps

- Update _userBubble to include role header
- Update _assistantBubble to include role header
- Headers show: icon, role label, and timestamp
- Robot icon for assistant, person icon for user
- Format: '助手@03-23 14:30' / '我@03-23 14:30'

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Add Resize Cursor Feedback

**Files:**
- Modify: `lib/ui/layout/right_chat_split_layout.dart:113-119`

- [ ] **Step 1: Add MouseRegion to drag handle**

Find the drag handle GestureDetector in `lib/ui/layout/right_chat_split_layout.dart` (around line 113):

Current code:
```dart
GestureDetector(
  key: const ValueKey('right-chat-drag-handle'),
  behavior: HitTestBehavior.opaque,
  onHorizontalDragUpdate: (details) =>
      _onResizeDragUpdate(details, windowWidth),
  child: const SizedBox(width: _dragHandleWidth),
),
```

Replace with:
```dart
MouseRegion(
  cursor: SystemMouseCursors.resizeLeftRight,
  child: GestureDetector(
    key: const ValueKey('right-chat-drag-handle'),
    behavior: HitTestBehavior.opaque,
    onHorizontalDragUpdate: (details) =>
        _onResizeDragUpdate(details, windowWidth),
    child: Container(
      width: _dragHandleWidth,
      color: Colors.transparent,
    ),
  ),
),
```

- [ ] **Step 2: Verify no syntax errors**

Run: `flutter analyze lib/ui/layout/right_chat_split_layout.dart`
Expected: No issues found

- [ ] **Step 3: Manual verification**

Run: `flutter run -d macos`
Steps:
1. Move mouse cursor over left edge of chat panel
2. Verify cursor changes to left-right resize arrows
3. Drag the edge to confirm it still works

- [ ] **Step 4: Commit**

```bash
git add lib/ui/layout/right_chat_split_layout.dart
git commit -m "feat: add resize cursor feedback to chat panel border

- Wrap drag handle with MouseRegion
- Display resizeLeftRight cursor on hover
- Improve UX by indicating resizable border

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Relocate Collapse Button to Left Border Center

**Files:**
- Modify: `lib/ui/layout/right_chat_split_layout.dart:107-145`

- [ ] **Step 1: Refactor expanded layout structure**

Find the expanded state layout in the `build` method (around line 107):

Current code structure:
```dart
SizedBox(
  key: const ValueKey('right-chat-panel'),
  width: rightWidth,
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GestureDetector(...),  // drag handle
      Expanded(
        child: Column(
          children: [
            SizedBox(...),  // collapse button at top
            Expanded(child: widget.rightChatPane),
          ],
        ),
      ),
    ],
  ),
),
```

Replace with:
```dart
SizedBox(
  key: const ValueKey('right-chat-panel'),
  width: rightWidth,
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          key: const ValueKey('right-chat-drag-handle'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) =>
              _onResizeDragUpdate(details, windowWidth),
          child: Container(
            width: _dragHandleWidth,
            color: Colors.transparent,
          ),
        ),
      ),
      Expanded(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.rightChatPane,
            Positioned(
              left: -8,
              top: 0,
              bottom: 0,
              child: Center(
                child: InkWell(
                  key: const ValueKey('right-chat-toggle-handle'),
                  onTap: () => _toggleChat(windowWidth),
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.chevron_right, size: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
),
```

Note: The collapse button at the top (lines 123-138 in current code) should be removed as it's now replaced by the centered version.

- [ ] **Step 2: Verify no syntax errors**

Run: `flutter analyze lib/ui/layout/right_chat_split_layout.dart`
Expected: No issues found

- [ ] **Step 3: Create widget test for button positioning**

Create `test/ui/layout/right_chat_split_layout_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/layout/right_chat_split_layout.dart';

void main() {
  group('RightChatSplitLayout', () {
    testWidgets('shows collapse button centered on left border when expanded',
        (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RightChatSplitLayout(
              leftPane: Container(color: Colors.blue),
              rightChatPane: Container(color: Colors.green),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Verify button is positioned on the left edge
      final button = tester.widget<Positioned>(
        find.ancestor(
          of: find.byIcon(Icons.chevron_right),
          matching: find.byType(Positioned),
        ),
      );
      expect(button.left, equals(-8));
    });

    testWidgets('collapse button toggles chat panel', (tester) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RightChatSplitLayout(
              leftPane: Container(color: Colors.blue),
              rightChatPane: Container(color: Colors.green),
            ),
          ),
        ),
      );

      // Act: Click collapse button
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      // Assert: Should show collapsed handle with left chevron
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    });
  });
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/ui/layout/right_chat_split_layout_test.dart`
Expected: PASS

- [ ] **Step 5: Manual verification**

Run: `flutter run -d macos`
Steps:
1. Verify collapse button appears on left edge, vertically centered
2. Click button to collapse chat panel
3. Verify button shows in center of collapsed handle
4. Click to expand, verify button returns to left edge center
5. Drag left edge to verify resize still works
6. Move cursor over left edge to verify resize cursor appears

- [ ] **Step 6: Commit**

```bash
git add lib/ui/layout/right_chat_split_layout.dart test/ui/layout/right_chat_split_layout_test.dart
git commit -m "feat: relocate collapse button to left border center

- Use Stack+Positioned to center button on left edge
- Button center aligns with 8px drag handle (left: -8)
- Removes top-positioned button for cleaner layout
- Maintains symmetry with collapsed state
- Preserves resize and toggle functionality

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Final Integration Testing

**Files:**
- Test: Manual verification

- [ ] **Step 1: Run all automated tests**

Run: `flutter test`
Expected: All tests PASS

- [ ] **Step 2: Full manual smoke test**

Run: `flutter run -d macos`

Checklist:
- [ ] App title shows "显微镜智能助手"
- [ ] User messages display person icon + "我@HH:MM"
- [ ] Assistant messages display robot icon + "助手@HH:MM"
- [ ] Time format is correct (MM-dd HH:mm)
- [ ] Message headers don't wrap on long messages
- [ ] Collapse button centered on left edge (expanded)
- [ ] Collapse button centered in handle (collapsed)
- [ ] Hovering over left edge shows resize cursor
- [ ] Dragging edge resizes panel smoothly
- [ ] Collapse/expand toggle works correctly
- [ ] All existing features still work

- [ ] **Step 3: Run code analysis**

Run: `flutter analyze`
Expected: No issues

- [ ] **Step 4: Verify formatting**

Run: `flutter format .`
Expected: Files formatted

- [ ] **Step 5: Final commit (if any format changes)**

```bash
git add -A
git commit -m "style: apply dart formatting

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Documentation Update

**Files:**
- Modify: `README.md` (if needed)

- [ ] **Step 1: Check if README needs updates**

Review `README.md` for references to "显微镜代理"

- [ ] **Step 2: Update README if applicable**

If found, update references to "显微镜智能助手"

- [ ] **Step 3: Commit (if changes made)**

```bash
git add README.md
git commit -m "docs: update app name in README

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Acceptance Criteria

All tasks complete when:
- ✅ All automated tests pass
- ✅ Manual smoke test passes with all checkboxes checked
- ✅ Code analysis shows no issues
- ✅ All commits follow conventional commit format
- ✅ Spec requirements fully implemented:
  - App title updated
  - Message headers with icons, roles, and timestamps
  - Collapse button repositioned
  - Resize cursor feedback added
- ✅ No regressions in existing functionality

---

## Implementation Notes

### Testing Strategy
- Widget tests for visual components (headers, layout)
- Integration tests for interactive elements (drag, toggle)
- Manual testing for cursor feedback and visual polish

### Future Extension Points
The `_MessageHeader` widget is designed for easy extension:
- Add `Image? avatar` parameter for custom avatars
- Add `String? displayName` parameter for custom names
- Add `VoidCallback? onTap` for avatar interactions

### Known Limitations
- Time stamps use device local timezone (no timezone conversion)
- Headers don't wrap - assume short display names
- Button positioning uses fixed offset (`left: -8`) based on 8px handle
