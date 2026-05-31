import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import '../ollama/ollama_dart.dart';

class ModelBrowserScreen extends StatefulWidget {
  const ModelBrowserScreen({super.key});

  @override
  State<ModelBrowserScreen> createState() => _ModelBrowserScreenState();
}

class _ModelBrowserScreenState extends State<ModelBrowserScreen> {
  final _searchController = TextEditingController();
  final _customModelController = TextEditingController();
  String _searchQuery = '';

  // Mock list of available models from Ollama library for browsing
  final List<_OllamaModelDef> _availableModels = [
    _OllamaModelDef(
      name: 'llama3.2',
      description: 'Meta\'s Llama 3.2, highly capable and fast.',
      sizes: ['1B', '3B'],
      tags: ['chat', 'reasoning'],
    ),
    _OllamaModelDef(
      name: 'mistral',
      description: 'The 7B model released by Mistral AI.',
      sizes: ['7B'],
      tags: ['chat', 'general'],
    ),
    _OllamaModelDef(
      name: 'gemma2',
      description: 'Google\'s Gemma 2 model.',
      sizes: ['2B', '9B', '27B'],
      tags: ['chat', 'code'],
    ),
    _OllamaModelDef(
      name: 'llava',
      description: 'Multimodal model capable of understanding images.',
      sizes: ['7B', '13B'],
      tags: ['multimodal', 'vision'],
    ),
    _OllamaModelDef(
      name: 'codellama',
      description: 'A large language model that can use text prompts to generate code.',
      sizes: ['7B', '13B', '34B', '70B'],
      tags: ['code'],
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _customModelController.dispose();
    super.dispose();
  }

  List<_OllamaModelDef> get _filteredModels {
    if (_searchQuery.isEmpty) return _availableModels;
    final q = _searchQuery.toLowerCase();
    return _availableModels
        .where((m) =>
            m.name.toLowerCase().contains(q) ||
            m.description.toLowerCase().contains(q))
        .toList();
  }

  void _downloadModel(String modelName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ModelDownloadDialog(modelName: modelName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Models'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                // Custom model pull input
                Card(
                  margin: const EdgeInsets.all(16),
                  color: colors.primaryContainer.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pull Custom Model',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enter any model tag from the Ollama library (e.g., deepseek-coder:6.7b, phi3:latest)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customModelController,
                                decoration: InputDecoration(
                                  hintText: 'model:tag',
                                  filled: true,
                                  fillColor: colors.surfaceContainer,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: () {
                                final tag = _customModelController.text.trim();
                                if (tag.isNotEmpty) {
                                  _downloadModel(tag);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please enter a valid model tag')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Pull'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search model list...',
                      filled: true,
                      fillColor: colors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredModels.length,
                    itemBuilder: (ctx, i) {
                      final model = _filteredModels[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.smart_toy_outlined, color: colors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    model.name,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const Spacer(),
                                  // Tags
                                  ...model.tags.map((tag) => Container(
                                        margin: const EdgeInsets.only(left: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colors.secondaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          tag,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colors.onSecondaryContainer,
                                            fontSize: 10,
                                          ),
                                        ),
                                      )),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                model.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: model.sizes.map((size) {
                                  final pullTag = '${model.name}:${size.toLowerCase()}';
                                  return OutlinedButton.icon(
                                    onPressed: () => _downloadModel(pullTag),
                                    icon: const Icon(Icons.download_rounded, size: 16),
                                    label: Text(size),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      minimumSize: const Size(0, 36),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OllamaModelDef {
  final String name;
  final String description;
  final List<String> sizes;
  final List<String> tags;

  _OllamaModelDef({
    required this.name,
    required this.description,
    required this.sizes,
    required this.tags,
  });
}

class ModelDownloadDialog extends StatefulWidget {
  final String modelName;
  const ModelDownloadDialog({super.key, required this.modelName});

  @override
  State<ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<ModelDownloadDialog> {
  StreamSubscription<ollama.StatusEvent>? _subscription;
  String _generalStatus = 'Initializing...';
  final Map<String, _LayerProgress> _layers = {};
  bool _isFinished = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  void _startDownload() {
    try {
      _subscription = OllamaService.instance.pullModel(widget.modelName).listen(
        (event) {
          if (mounted) {
            setState(() {
              _generalStatus = event.status ?? 'Downloading...';
              if (event.digest != null) {
                final digest = event.digest!;
                _layers[digest] = _LayerProgress(
                  digest: digest,
                  status: event.status ?? 'processing',
                  completed: event.completed ?? 0,
                  total: event.total ?? 0,
                );
              }
              if (event.status == 'success') {
                _isFinished = true;
                _generalStatus = 'Completed successfully!';
              }
            });
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _errorMessage = err.toString();
              _generalStatus = 'Failed';
            });
          }
        },
        onDone: () {
          if (mounted && !_isFinished && _errorMessage == null) {
            setState(() {
              _isFinished = true;
              _generalStatus = 'Completed';
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _generalStatus = 'Error starting pull';
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final layersList = _layers.values.toList();
    // Sort so active downloads are at the top, followed by success/done
    layersList.sort((a, b) {
      if (a.status == 'success' && b.status != 'success') return 1;
      if (b.status == 'success' && a.status != 'success') return -1;
      return b.completed.compareTo(a.completed);
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pulling Model',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                widget.modelName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                _generalStatus,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (!_isFinished && _errorMessage == null && layersList.isEmpty)
                const LinearProgressIndicator(),
              if (layersList.isNotEmpty) ...[
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: layersList.length,
                    itemBuilder: (ctx, idx) {
                      final layer = layersList[idx];
                      final shortDigest = layer.digest.length > 15
                          ? '${layer.digest.substring(0, 7)}...${layer.digest.substring(layer.digest.length - 8)}'
                          : layer.digest;
                      final isSuccess = layer.status == 'success';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isSuccess ? Icons.check_circle_rounded : Icons.downloading_rounded,
                                  size: 16,
                                  color: isSuccess ? Colors.green : colors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  shortDigest,
                                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                ),
                                const Spacer(),
                                Text(
                                  isSuccess
                                      ? 'Done'
                                      : '${_formatBytes(layer.completed)} / ${_formatBytes(layer.total)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            if (!isSuccess && layer.total > 0) ...[
                              const SizedBox(height: 4),
                              LinearProgressIndicator(value: layer.progress),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!_isFinished && _errorMessage == null)
                    OutlinedButton(
                      onPressed: () {
                        _subscription?.cancel();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Cancelled pulling ${widget.modelName}')),
                        );
                      },
                      child: const Text('Cancel'),
                    ),
                  if (_isFinished || _errorMessage != null)
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerProgress {
  final String digest;
  final String status;
  final int completed;
  final int total;

  _LayerProgress({
    required this.digest,
    required this.status,
    required this.completed,
    required this.total,
  });

  double get progress => total > 0 ? completed / total : 0.0;
}
