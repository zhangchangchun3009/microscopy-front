import 'package:flutter_test/flutter_test.dart';
import 'package:microscope_app/ui/chat/chat_models.dart';

void main() {
  group('SystemMessage', () {
    test('should create system message with required fields', () {
      final msg = SystemMessage(
        content: 'Test message',
        time: DateTime(2026, 4, 10, 10, 30),
        type: SystemMessageType.info,
      );

      expect(msg.content, 'Test message');
      expect(msg.type, SystemMessageType.info);
      expect(msg.time, DateTime(2026, 4, 10, 10, 30));
    });

    test('should support all system message types', () {
      final types = SystemMessageType.values;

      expect(types, contains(SystemMessageType.info));
      expect(types, contains(SystemMessageType.success));
      expect(types, contains(SystemMessageType.warning));
      expect(types, contains(SystemMessageType.progress));
    });

    test('should implement equality correctly', () {
      final time = DateTime(2026, 4, 10, 10, 30);
      final msg1 = SystemMessage(
        content: 'Test',
        time: time,
        type: SystemMessageType.info,
      );
      final msg2 = SystemMessage(
        content: 'Test',
        time: time,
        type: SystemMessageType.info,
      );
      final msg3 = SystemMessage(
        content: 'Different',
        time: time,
        type: SystemMessageType.info,
      );

      expect(msg1, equals(msg2));
      expect(msg1, isNot(equals(msg3)));
    });

    test('should copyWith correctly', () {
      final time = DateTime(2026, 4, 10, 10, 30);
      final msg = SystemMessage(
        content: 'Test',
        time: time,
        type: SystemMessageType.info,
      );

      final copied = msg.copyWith(content: 'Updated');

      expect(copied.content, 'Updated');
      expect(copied.time, time);
      expect(copied.type, SystemMessageType.info);
    });

    test('should provide readable toString', () {
      final msg = SystemMessage(
        content: 'Test',
        time: DateTime(2026, 4, 10, 10, 30),
        type: SystemMessageType.info,
      );

      final str = msg.toString();
      expect(str, contains('SystemMessage'));
      expect(str, contains('Test'));
      expect(str, contains('info'));
    });
  });
}
