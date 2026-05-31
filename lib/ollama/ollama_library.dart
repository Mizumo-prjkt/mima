import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for browsing the public Ollama model library at ollama.com.
/// This is separate from OllamaService which talks to the local Ollama server.
class OllamaLibrary {
  OllamaLibrary._();
  static final OllamaLibrary instance = OllamaLibrary._();

  static const String _baseUrl = 'https://ollama.com';

  /// Fetches featured/trending models from the Ollama registry.
  /// Returns parsed JSON model entries.
  Future<List<LibraryModel>> fetchFeaturedModels() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/tags'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final data = jsonDecode(res.body);
      final models = data['models'] as List<dynamic>? ?? [];
      return models.map((m) => LibraryModel.fromTagsJson(m)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Searches the Ollama library by parsing the HTML search page.
  /// Returns a list of models matching the query.
  Future<List<LibrarySearchResult>> searchModels(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$_baseUrl/search').replace(
        queryParameters: {'q': query},
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      return parseSearchResults(res.body);
    } catch (e) {
      return [];
    }
  }

  /// Fetches model detail info from the library page.
  /// Extracts the developer description/summary and available tags.
  Future<LibraryModelDetail?> fetchModelDetail(String modelName) async {
    // Strip tag suffix for the library page (e.g. "gemma3:4b" -> "gemma3")
    final baseName = modelName.split(':').first;
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/library/$baseName'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return parseModelDetail(baseName, res.body);
    } catch (e) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // HTML Parsing helpers (lightweight regex-based, no external dependencies)
  // ---------------------------------------------------------------------------

  List<LibrarySearchResult> parseSearchResults(String html) {
    final results = <LibrarySearchResult>[];

    // Each model result is in a <li x-test-model> block
    final modelBlocks = RegExp(
      r'<li x-test-model.*?</li>',
      dotAll: true,
    ).allMatches(html);

    for (final block in modelBlocks) {
      final blockHtml = block.group(0) ?? '';

      // Title
      final titleMatch = RegExp(
        r'<span x-test-search-response-title>(.*?)</span>',
      ).firstMatch(blockHtml);
      final name = titleMatch?.group(1)?.trim() ?? '';
      if (name.isEmpty) continue;

      // Description
      final descMatch = RegExp(
        r'<p class="max-w-lg break-words text-neutral-800[^"]*">(.*?)</p>',
        dotAll: true,
      ).firstMatch(blockHtml);
      final description = stripHtml(descMatch?.group(1)?.trim() ?? '');

      // Capabilities (vision, tools, thinking, etc.)
      final capabilities = <String>[];
      for (final cap in RegExp(
        r'<span x-test-capability[^>]*>(.*?)</span>',
      ).allMatches(blockHtml)) {
        final c = cap.group(1)?.trim() ?? '';
        if (c.isNotEmpty) capabilities.add(c);
      }

      // Sizes
      final sizes = <String>[];
      for (final size in RegExp(
        r'<span x-test-size[^>]*>(.*?)</span>',
      ).allMatches(blockHtml)) {
        final s = size.group(1)?.trim() ?? '';
        if (s.isNotEmpty) sizes.add(s);
      }

      // Pull count
      final pullMatch = RegExp(
        r'<span x-test-pull-count>(.*?)</span>',
      ).firstMatch(blockHtml);
      final pullCount = pullMatch?.group(1)?.trim() ?? '';

      // Updated
      final updatedMatch = RegExp(
        r'<span x-test-updated>(.*?)</span>',
      ).firstMatch(blockHtml);
      final updatedAt = updatedMatch?.group(1)?.trim() ?? '';

      results.add(LibrarySearchResult(
        name: name,
        description: description,
        capabilities: capabilities,
        sizes: sizes,
        pullCount: pullCount,
        updatedAt: updatedAt,
      ));
    }
    return results;
  }

  LibraryModelDetail? parseModelDetail(String name, String html) {
    // Extract the meta description
    final metaMatch = RegExp(
      r'<meta name="description" content="(.*?)"',
    ).firstMatch(html);
    final metaDesc = metaMatch?.group(1) ?? '';

    // Extract the summary content
    final summaryMatch = RegExp(
      r'<span id="summary-content">\s*(.*?)\s*</span>',
      dotAll: true,
    ).firstMatch(html);
    final summary = stripHtml(summaryMatch?.group(1)?.trim() ?? metaDesc);

    // Extract capabilities/tags
    final capabilities = <String>[];
    // Look for capability badges in the tag section near the summary
    final tagSection = RegExp(
      r'<div class="flex flex-wrap gap-2">(.*?)</div>',
      dotAll: true,
    ).firstMatch(html);
    if (tagSection != null) {
      for (final cap in RegExp(
        r'font-medium[^>]*>(.*?)</span>',
      ).allMatches(tagSection.group(1) ?? '')) {
        final c = cap.group(1)?.trim() ?? '';
        if (c.isNotEmpty) capabilities.add(c);
      }
    }

    // Extract available model tags/sizes from the models table
    final modelTags = <String>[];
    for (final tag in RegExp(
      r'<input class="command hidden" value="(.*?)"',
    ).allMatches(html)) {
      final t = tag.group(1)?.trim() ?? '';
      if (t.isNotEmpty) modelTags.add(t);
    }

    // Extract pull count from the detail page
    final pullMatch = RegExp(
      r'<span x-test-pull-count>(.*?)</span>',
    ).firstMatch(html);
    final pullCount = pullMatch?.group(1)?.trim() ?? '';

    // Extract updated date
    final updatedMatch = RegExp(
      r'<span x-test-updated>(.*?)</span>',
    ).firstMatch(html);
    final updatedAt = updatedMatch?.group(1)?.trim() ?? '';

    return LibraryModelDetail(
      name: name,
      summary: summary,
      capabilities: capabilities,
      availableTags: modelTags,
      pullCount: pullCount,
      updatedAt: updatedAt,
    );
  }

  String stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

/// A model entry from the /api/tags endpoint.
class LibraryModel {
  final String name;
  final String model;
  final int size;
  final String digest;
  final String modifiedAt;

  LibraryModel({
    required this.name,
    required this.model,
    required this.size,
    required this.digest,
    required this.modifiedAt,
  });

  factory LibraryModel.fromTagsJson(Map<String, dynamic> json) {
    return LibraryModel(
      name: json['name'] as String? ?? '',
      model: json['model'] as String? ?? '',
      size: json['size'] as int? ?? 0,
      digest: json['digest'] as String? ?? '',
      modifiedAt: json['modified_at'] as String? ?? '',
    );
  }

  String get displaySize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// A search result parsed from the HTML search page.
class LibrarySearchResult {
  final String name;
  final String description;
  final List<String> capabilities;
  final List<String> sizes;
  final String pullCount;
  final String updatedAt;

  LibrarySearchResult({
    required this.name,
    required this.description,
    required this.capabilities,
    required this.sizes,
    required this.pullCount,
    required this.updatedAt,
  });
}

/// Detailed model information from the library page.
class LibraryModelDetail {
  final String name;
  final String summary;
  final List<String> capabilities;
  final List<String> availableTags;
  final String pullCount;
  final String updatedAt;

  LibraryModelDetail({
    required this.name,
    required this.summary,
    required this.capabilities,
    required this.availableTags,
    required this.pullCount,
    required this.updatedAt,
  });
}
