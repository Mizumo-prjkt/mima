import 'package:flutter_test/flutter_test.dart';
import 'package:mima/ollama/ollama_library.dart';

void main() {
  group('OllamaLibrary html parsing', () {
    test('stripHtml strips tags and replaces entities', () {
      final library = OllamaLibrary.instance;
      expect(library.stripHtml('<p>Hello <b>World</b></p>'), 'Hello World');
      expect(library.stripHtml('A &amp; B &lt; C &gt; D &quot; E &#39; F &nbsp; G'), "A & B < C > D \" E ' F G");
      expect(library.stripHtml('   too   many    spaces   '), 'too many spaces');
    });

    test('parseSearchResults parses model entries correctly', () {
      const html = '''
<li x-test-model class="flex items-baseline border-b border-neutral-200 py-6">
  <a href="/library/gemma4" class="group w-full">
    <div class="flex flex-col mb-1" title="gemma4">
      <h2 class="truncate text-xl font-medium underline-offset-2 group-hover:underline md:text-2xl">
        <span x-test-search-response-title>gemma4</span>
      </h2>
      <p class="max-w-lg break-words text-neutral-800 text-md">Gemma 4 models are designed to deliver frontier-level performance.</p>
    </div>
    <div class="flex flex-col">
      <div class="flex flex-wrap space-x-2">
        <span x-test-capability class="cap">vision</span>
        <span x-test-capability class="cap">tools</span>
        <span x-test-size class="size">26b</span>
        <span x-test-size class="size">31b</span>
      </div>
      <p class="my-1">
        <span x-test-pull-count>11.3M</span>
        <span x-test-updated>1 week ago</span>
      </p>
    </div>
  </a>
</li>
''';

      final results = OllamaLibrary.instance.parseSearchResults(html);
      expect(results, hasLength(1));
      final model = results.first;
      expect(model.name, 'gemma4');
      expect(model.description, 'Gemma 4 models are designed to deliver frontier-level performance.');
      expect(model.capabilities, containsAll(['vision', 'tools']));
      expect(model.sizes, containsAll(['26b', '31b']));
      expect(model.pullCount, '11.3M');
      expect(model.updatedAt, '1 week ago');
    });

    test('parseModelDetail parses detail information correctly', () {
      const html = '''
<!doctype html>
<html>
  <head>
    <meta name="description" content="Meta summary description for gemma3." />
  </head>
  <body>
    <span id="summary-content">
      Detailed summary of Gemma 3 model page.
    </span>
    <div class="flex flex-wrap gap-2">
      <span class="font-medium">vision</span>
      <span class="font-medium">tools</span>
    </div>
    <table>
      <input class="command hidden" value="ollama run gemma3:1b" />
      <input class="command hidden" value="ollama run gemma3:4b" />
    </table>
    <span x-test-pull-count>37.2M</span>
    <span x-test-updated>5 months ago</span>
  </body>
</html>
''';

      final detail = OllamaLibrary.instance.parseModelDetail('gemma3', html);
      expect(detail, isNotNull);
      expect(detail!.name, 'gemma3');
      expect(detail.summary, 'Detailed summary of Gemma 3 model page.');
      expect(detail.capabilities, containsAll(['vision', 'tools']));
      expect(detail.availableTags, containsAll(['ollama run gemma3:1b', 'ollama run gemma3:4b']));
      expect(detail.pullCount, '37.2M');
      expect(detail.updatedAt, '5 months ago');
    });

    test('parseModelDetail falls back to meta description if summary-content is missing', () {
      const html = '''
<!doctype html>
<html>
  <head>
    <meta name="description" content="Fallback meta description" />
  </head>
  <body>
  </body>
</html>
''';

      final detail = OllamaLibrary.instance.parseModelDetail('gemma3', html);
      expect(detail, isNotNull);
      expect(detail!.summary, 'Fallback meta description');
    });
  });
}
