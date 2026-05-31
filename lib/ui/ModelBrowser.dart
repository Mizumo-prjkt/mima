import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import '../ollama/ollama_dart.dart';
import '../ollama/ollama_library.dart';

class ModelBrowserScreen extends StatefulWidget {
  const ModelBrowserScreen({super.key});

  @override
  State<ModelBrowserScreen> createState() => _ModelBrowserScreenState();
}

class _ModelBrowserScreenState extends State<ModelBrowserScreen> {
  final _searchController = TextEditingController();
  final _customModelController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSearching = false;

  List<LibrarySearchResult> _searchResults = [];
  List<LibraryModel> _featuredModels = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadFeatured();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customModelController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
    setState(() => _isLoading = true);
    final models = await OllamaLibrary.instance.fetchFeaturedModels();
    if (mounted) {
      setState(() {
        _featuredModels = models;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    final results = await OllamaLibrary.instance.searchModels(query);
    if (mounted && _searchQuery == query) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  void _downloadModel(String modelName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ModelDownloadDialog(modelName: modelName),
    );
  }

  void _showModelDetail(String modelName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModelDetailSheet(
        modelName: modelName,
        onDownload: (tag) {
          Navigator.pop(ctx);
          _downloadModel(tag);
        },
      ),
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
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: 'Search Ollama library...',
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
                                _onSearchChanged('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: _buildContent(theme, colors),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, ColorScheme colors) {
    if (_isLoading || _isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show search results if query is active
    if (_searchQuery.isNotEmpty) {
      if (_searchResults.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                'No models found for "$_searchQuery"',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _searchResults.length,
        itemBuilder: (ctx, i) => _buildSearchResultCard(_searchResults[i], theme, colors),
      );
    }

    // Show featured models
    if (_featuredModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: colors.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Could not load model library',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loadFeatured,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _featuredModels.length + 1, // +1 for header
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Featured Models',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          );
        }
        final model = _featuredModels[i - 1];
        return _buildFeaturedModelCard(model, theme, colors);
      },
    );
  }

  Widget _buildSearchResultCard(LibrarySearchResult model, ThemeData theme, ColorScheme colors) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showModelDetail(model.name),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: colors.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      model.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.onSurface.withValues(alpha: 0.3)),
                ],
              ),
              if (model.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  model.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...model.capabilities.map((cap) => _CapabilityChip(label: cap, colors: colors)),
                  ...model.sizes.map((size) => _SizeChip(label: size, colors: colors)),
                ],
              ),
              if (model.pullCount.isNotEmpty || model.updatedAt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (model.pullCount.isNotEmpty) ...[
                      Icon(Icons.download_rounded, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                        '${model.pullCount} pulls',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                    if (model.pullCount.isNotEmpty && model.updatedAt.isNotEmpty)
                      const SizedBox(width: 16),
                    if (model.updatedAt.isNotEmpty) ...[
                      Icon(Icons.access_time_rounded, size: 14, color: colors.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                        model.updatedAt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedModelCard(LibraryModel model, ThemeData theme, ColorScheme colors) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showModelDetail(model.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.smart_toy_outlined, color: colors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      model.displaySize,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _downloadModel(model.name),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Pull'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: colors.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Chip widgets
// =============================================================================

class _CapabilityChip extends StatelessWidget {
  final String label;
  final ColorScheme colors;
  const _CapabilityChip({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.tertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: colors.tertiary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  final String label;
  final ColorScheme colors;
  const _SizeChip({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: colors.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// =============================================================================
// Model Detail Bottom Sheet
// =============================================================================

class _ModelDetailSheet extends StatefulWidget {
  final String modelName;
  final void Function(String tag) onDownload;

  const _ModelDetailSheet({required this.modelName, required this.onDownload});

  @override
  State<_ModelDetailSheet> createState() => _ModelDetailSheetState();
}

class _ModelDetailSheetState extends State<_ModelDetailSheet> {
  LibraryModelDetail? _detail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final detail = await OllamaLibrary.instance.fetchModelDetail(widget.modelName);
    if (mounted) {
      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy_rounded, color: colors.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.modelName,
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _detail == null
                        ? Center(
                            child: Text(
                              'Could not load model details',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.all(24),
                            children: [
                              // Summary / developer description
                              if (_detail!.summary.isNotEmpty) ...[
                                Text(
                                  'About',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: colors.outlineVariant.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    _detail!.summary,
                                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Stats row
                              if (_detail!.pullCount.isNotEmpty || _detail!.updatedAt.isNotEmpty) ...[
                                Row(
                                  children: [
                                    if (_detail!.pullCount.isNotEmpty)
                                      _StatItem(
                                        icon: Icons.download_rounded,
                                        label: '${_detail!.pullCount} downloads',
                                        colors: colors,
                                      ),
                                    if (_detail!.pullCount.isNotEmpty && _detail!.updatedAt.isNotEmpty)
                                      const SizedBox(width: 24),
                                    if (_detail!.updatedAt.isNotEmpty)
                                      _StatItem(
                                        icon: Icons.access_time_rounded,
                                        label: 'Updated ${_detail!.updatedAt}',
                                        colors: colors,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Capabilities
                              if (_detail!.capabilities.isNotEmpty) ...[
                                Text(
                                  'Capabilities',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _detail!.capabilities
                                      .map((cap) => _CapabilityChip(label: cap, colors: colors))
                                      .toList(),
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Available tags — download buttons
                              if (_detail!.availableTags.isNotEmpty) ...[
                                Text(
                                  'Available Variants',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                ..._detail!.availableTags.map((tag) => Card(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      child: ListTile(
                                        dense: true,
                                        title: Text(
                                          tag,
                                          style: const TextStyle(fontWeight: FontWeight.w500, fontFamily: 'monospace'),
                                        ),
                                        trailing: OutlinedButton.icon(
                                          onPressed: () => widget.onDownload(tag),
                                          icon: const Icon(Icons.download_rounded, size: 16),
                                          label: const Text('Pull'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            minimumSize: const Size(0, 34),
                                          ),
                                        ),
                                      ),
                                    )),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colors;
  const _StatItem({required this.icon, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

// =============================================================================
// Model Download Dialog (reused from before, with layer progress tracking)
// =============================================================================

class _ModelDownloadDialog extends StatefulWidget {
  final String modelName;
  const _ModelDownloadDialog({required this.modelName});

  @override
  State<_ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<_ModelDownloadDialog> {
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
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final layersList = _layers.values.toList();
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
