import 'package:flutter_test/flutter_test.dart';
import 'package:mima/ollama/ollama_dart.dart';

void main() {
  group('OllamaService', () {
    test('defaultServerUrl is a valid URL', () {
      final url = Uri.tryParse(OllamaService.defaultServerUrl);
      expect(url, isNotNull);
      expect(url!.hasScheme, isTrue);
      expect(url.host, isNotEmpty);
      expect(url.port, equals(11434));
    });

    test('singleton instance is consistent', () {
      final a = OllamaService.instance;
      final b = OllamaService.instance;
      expect(identical(a, b), isTrue);
    });
  });

  group('URL configuration', () {
    test('defaultServerUrl uses http scheme', () {
      expect(OllamaService.defaultServerUrl, startsWith('http://'));
    });

    test('defaultServerUrl contains expected port', () {
      expect(OllamaService.defaultServerUrl, contains(':11434'));
    });
  });
}
