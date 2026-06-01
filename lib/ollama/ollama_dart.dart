import 'package:ollama_dart/ollama_dart.dart' as ollama;
import 'package:http/http.dart' as http;
import '../store/store.dart';

class OllamaService {
  OllamaService._();
  static final OllamaService instance = OllamaService._();

  /// Default server URL used only when no user-configured URL exists.
  /// Users on a local intranet should set their own address via Setup/Settings.
  static const String defaultServerUrl = 'http://localhost:11434';

  ollama.OllamaClient? _client;
  String? _lastUrl;

  /// Returns the currently configured server URL from the database,
  /// falling back to [defaultServerUrl] if none has been saved yet.
  Future<String> getServerUrl() async {
    return await MimaStore.instance.getSetting('server_url') ??
        defaultServerUrl;
  }

  Future<ollama.OllamaClient> getClient() async {
    final url = await getServerUrl();
    if (_client == null || _lastUrl != url) {
      _client?.close();
      _client = ollama.OllamaClient(
        config: ollama.OllamaConfig(baseUrl: url),
      );
      _lastUrl = url;
    }
    return _client!;
  }

  /// Check connectivity of Ollama server.
  Future<bool> testConnection(String url) async {
    try {
      final client = ollama.OllamaClient(
        config: ollama.OllamaConfig(baseUrl: url),
      );
      // Timeout after 5 seconds to prevent locking the UI
      await client.models.list().timeout(const Duration(seconds: 5));
      client.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Lists all downloaded models currently available locally.
  Future<List<ollama.ModelSummary>> listModels() async {
    try {
      final client = await getClient();
      final res = await client.models.list();
      return res.models ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Deletes a local model from Ollama.
  Future<bool> deleteModel(String modelName) async {
    try {
      final client = await getClient();
      await client.models.delete(
        request: ollama.DeleteRequest(model: modelName),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Pulls/downloads a model from the Ollama library.
  /// Uses a separate client with infinite timeout to prevent early termination.
  Stream<ollama.StatusEvent> pullModel(String modelName) async* {
    final url = await getServerUrl();
    final httpClient = http.Client();
    final client = ollama.OllamaClient(
      config: ollama.OllamaConfig(baseUrl: url),
      httpClient: httpClient,
    );

    try {
      final stream = client.models.pullStream(
        request: ollama.PullRequest(model: modelName),
      );
      await for (final update in stream) {
        yield update;
      }
    } finally {
      client.close();
      httpClient.close();
    }
  }

  /// Streams chat completions using model parameters.
  Stream<String> streamChatCompletion({
    required String model,
    required List<ollama.ChatMessage> messages,
    double? temperature,
    String? systemPrompt,
  }) async* {
    final client = await getClient();

    final allMessages = <ollama.ChatMessage>[];
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      allMessages.add(ollama.ChatMessage.system(systemPrompt));
    }
    allMessages.addAll(messages);

    final request = ollama.ChatRequest(
      model: model,
      messages: allMessages,
      options: ollama.ModelOptions(
        temperature: temperature,
      ),
    );

    final stream = client.chat.createStream(request: request);
    await for (final chunk in stream) {
      final text = chunk.message?.content;
      if (text != null) {
        yield text;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Diagnostics helpers
  // ---------------------------------------------------------------------------

  /// Returns the Ollama server version string.
  Future<String?> getServerVersion() async {
    try {
      final client = await getClient();
      final res = await client.version.get().timeout(const Duration(seconds: 5));
      return res.version;
    } catch (e) {
      return null;
    }
  }

  /// Returns currently running/loaded models with VRAM usage info.
  Future<List<ollama.RunningModel>> getRunningModels() async {
    try {
      final client = await getClient();
      final res = await client.models.ps().timeout(const Duration(seconds: 5));
      return res.models ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Shows detailed info for a specific model (params, quant, capabilities).
  Future<ollama.ShowResponse?> showModelInfo(String modelName) async {
    try {
      final client = await getClient();
      final res = await client.models.show(
        request: ollama.ShowRequest(model: modelName),
      ).timeout(const Duration(seconds: 10));
      return res;
    } catch (e) {
      return null;
    }
  }

  /// Benchmarks a model by sending a fixed prompt and measuring tokens/sec.
  /// Returns a [BenchmarkResult] with timing and token count.
  Future<BenchmarkResult> benchmarkModel(String modelName) async {
    const benchmarkPrompt = 'Explain quantum computing in exactly 100 words.';
    final client = await getClient();

    final request = ollama.ChatRequest(
      model: modelName,
      messages: [ollama.ChatMessage.user(benchmarkPrompt)],
      options: const ollama.ModelOptions(temperature: 0.7),
    );

    final stopwatch = Stopwatch()..start();
    int tokenCount = 0;
    final buffer = StringBuffer();

    final stream = client.chat.createStream(request: request);
    await for (final chunk in stream) {
      final text = chunk.message?.content;
      if (text != null && text.isNotEmpty) {
        tokenCount++;
        buffer.write(text);
      }
    }
    stopwatch.stop();

    final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
    return BenchmarkResult(
      modelName: modelName,
      tokenCount: tokenCount,
      elapsedSeconds: elapsedSec,
      tokensPerSecond: elapsedSec > 0 ? tokenCount / elapsedSec : 0,
      response: buffer.toString(),
    );
  }
}

/// Result of a model benchmark run.
class BenchmarkResult {
  final String modelName;
  final int tokenCount;
  final double elapsedSeconds;
  final double tokensPerSecond;
  final String response;

  const BenchmarkResult({
    required this.modelName,
    required this.tokenCount,
    required this.elapsedSeconds,
    required this.tokensPerSecond,
    required this.response,
  });
}
