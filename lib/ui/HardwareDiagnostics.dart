import 'package:flutter/material.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import '../ollama/ollama_dart.dart';
import '../main.dart';

// =============================================================================
// HardwareDiagnosticsScreen — Probes Ollama server capabilities and
// recommends models suited to the detected hardware.
// =============================================================================

class HardwareDiagnosticsScreen extends StatefulWidget {
  const HardwareDiagnosticsScreen({super.key});

  @override
  State<HardwareDiagnosticsScreen> createState() =>
      _HardwareDiagnosticsScreenState();
}

class _HardwareDiagnosticsScreenState extends State<HardwareDiagnosticsScreen>
    with SingleTickerProviderStateMixin {
  // ---- state ----------------------------------------------------------------
  bool _loading = true;
  String? _serverVersion;
  String _serverUrl = OllamaService.defaultServerUrl;
  bool _serverOnline = false;

  List<ollama.ModelSummary> _installedModels = [];
  List<ollama.RunningModel> _runningModels = [];
  Map<String, ollama.ShowResponse> _modelDetails = {};

  int _estimatedVramBytes = 0;
  bool _gpuDetected = false;

  // benchmark
  bool _benchmarking = false;
  String? _benchmarkingModel;
  List<BenchmarkResult> _benchmarkResults = [];

  late final AnimationController _entryCtrl;

  // ---- lifecycle ------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _runDiagnostics();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  // ---- data gathering -------------------------------------------------------

  Future<void> _runDiagnostics() async {
    setState(() => _loading = true);

    // 1. Server URL & version
    _serverUrl = await OllamaService.instance.getServerUrl();
    _serverVersion = await OllamaService.instance.getServerVersion();
    _serverOnline = _serverVersion != null;

    if (!_serverOnline) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // 2. Installed models
    _installedModels = await OllamaService.instance.listModels();

    // 3. Running models (VRAM detection)
    _runningModels = await OllamaService.instance.getRunningModels();
    _detectVram();

    // 4. Model details (in parallel)
    final futures = <Future>[];
    for (final m in _installedModels) {
      final name = m.name ?? '';
      if (name.isEmpty) continue;
      futures.add(
        OllamaService.instance.showModelInfo(name).then((info) {
          if (info != null) _modelDetails[name] = info;
        }),
      );
    }
    await Future.wait(futures);

    if (mounted) setState(() => _loading = false);
  }

  void _detectVram() {
    // Look at running models for VRAM info
    int maxVram = 0;
    for (final rm in _runningModels) {
      final vram = rm.sizeVram ?? 0;
      if (vram > maxVram) maxVram = vram;
      if (vram > 0) _gpuDetected = true;
    }
    // Estimate total VRAM as the max VRAM we've seen used, with headroom
    // This is an approximation since Ollama doesn't expose total VRAM directly
    _estimatedVramBytes = maxVram;
  }

  Future<void> _runBenchmark() async {
    if (_installedModels.isEmpty) return;
    setState(() {
      _benchmarking = true;
      _benchmarkResults = [];
    });

    for (final model in _installedModels) {
      final name = model.name ?? '';
      if (name.isEmpty) continue;

      setState(() => _benchmarkingModel = name);
      try {
        final result = await OllamaService.instance.benchmarkModel(name);
        if (mounted) {
          setState(() => _benchmarkResults.add(result));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _benchmarkResults.add(BenchmarkResult(
                modelName: name,
                tokenCount: 0,
                elapsedSeconds: 0,
                tokensPerSecond: 0,
                response: 'Error: $e',
              )));
        }
      }

      // Refresh running models after loading this model (for VRAM detection)
      _runningModels = await OllamaService.instance.getRunningModels();
      _detectVram();
    }

    if (mounted) {
      setState(() {
        _benchmarking = false;
        _benchmarkingModel = null;
        // Sort results by tokens/sec descending
        _benchmarkResults.sort((a, b) =>
            b.tokensPerSecond.compareTo(a.tokensPerSecond));
      });
    }
  }

  // ---- helpers --------------------------------------------------------------

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  double _bytesToGB(int bytes) => bytes / (1024 * 1024 * 1024);

  _ModelFitness _getModelFitness(ollama.ModelSummary model) {
    final modelSize = model.size ?? 0;
    if (_estimatedVramBytes <= 0) return _ModelFitness.unknown;
    if (modelSize <= _estimatedVramBytes) return _ModelFitness.fitsVram;
    if (modelSize <= _estimatedVramBytes * 1.5) return _ModelFitness.partialOffload;
    return _ModelFitness.cpuOnly;
  }

  // ---- build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hardware Diagnostics'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _runDiagnostics,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Re-run diagnostics',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut),
        child: _loading
            ? const Center(child: _LoadingIndicator())
            : SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 800;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),
                          child: isWide
                              ? _buildWideLayout()
                              : _buildNarrowLayout(),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Column(
      children: [
        // Top row: server + hardware side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildServerCard()),
            const SizedBox(width: 16),
            Expanded(child: _buildHardwareCard()),
          ],
        ),
        const SizedBox(height: 16),
        _buildModelsCard(),
        const SizedBox(height: 16),
        _buildBenchmarkCard(),
        const SizedBox(height: 16),
        _buildRecommendationsCard(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _buildServerCard(),
        const SizedBox(height: 16),
        _buildHardwareCard(),
        const SizedBox(height: 16),
        _buildModelsCard(),
        const SizedBox(height: 16),
        _buildBenchmarkCard(),
        const SizedBox(height: 16),
        _buildRecommendationsCard(),
        const SizedBox(height: 32),
      ],
    );
  }

  // ---- 1. Server Status Card ------------------------------------------------

  Widget _buildServerCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _DiagCard(
      icon: Icons.dns_rounded,
      title: 'Server Status',
      accentColor: _serverOnline ? colors.primary : colors.error,
      children: [
        _InfoRow(
          label: 'Status',
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _serverOnline
                      ? const Color(0xFF4CAF50)
                      : colors.error,
                  boxShadow: [
                    BoxShadow(
                      color: (_serverOnline
                              ? const Color(0xFF4CAF50)
                              : colors.error)
                          .withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _serverOnline ? 'Online' : 'Offline',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _serverOnline
                      ? const Color(0xFF4CAF50)
                      : colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _InfoRow(
          label: 'URL',
          value: _serverUrl,
        ),
        if (_serverVersion != null)
          _InfoRow(
            label: 'Ollama Version',
            value: _serverVersion!,
          ),
        if (!_serverOnline)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.error.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: colors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cannot reach the Ollama server. Check that it is running and the URL is correct.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---- 2. Hardware Detection Card -------------------------------------------

  Widget _buildHardwareCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final totalDisk =
        _installedModels.fold<int>(0, (sum, m) => sum + (m.size ?? 0));

    return _DiagCard(
      icon: Icons.memory_rounded,
      title: 'Hardware Detection',
      accentColor: colors.tertiary,
      children: [
        _InfoRow(
          label: 'GPU Acceleration',
          child: Row(
            children: [
              Icon(
                _gpuDetected
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 18,
                color: _gpuDetected
                    ? const Color(0xFF4CAF50)
                    : colors.onSurface.withOpacity(0.3),
              ),
              const SizedBox(width: 8),
              Text(
                _gpuDetected ? 'Active' : 'Not detected',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _gpuDetected
                      ? const Color(0xFF4CAF50)
                      : colors.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        _InfoRow(
          label: 'VRAM Used by Models',
          value: _estimatedVramBytes > 0
              ? _formatBytes(_estimatedVramBytes)
              : 'Unknown — load a model to detect',
        ),
        _InfoRow(
          label: 'Models Loaded',
          value: '${_runningModels.length}',
        ),
        _InfoRow(
          label: 'Total Disk Used',
          value: _formatBytes(totalDisk),
        ),
        if (_estimatedVramBytes <= 0 && _installedModels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.tertiary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.tertiary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: colors.tertiary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Run a benchmark below to load models and detect VRAM.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ---- 3. Installed Models Analysis -----------------------------------------

  Widget _buildModelsCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _DiagCard(
      icon: Icons.smart_toy_rounded,
      title: 'Installed Models',
      accentColor: colors.secondary,
      children: [
        if (_installedModels.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.download_rounded,
                      size: 40, color: colors.onSurface.withOpacity(0.15)),
                  const SizedBox(height: 12),
                  Text(
                    'No models installed',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/models/browse'),
                    child: const Text('Browse Models'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Table header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Model',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.4),
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Params',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.4),
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Quant',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.4),
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Size',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.4),
                      )),
                ),
                const SizedBox(width: 80, child: SizedBox.shrink()),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant.withOpacity(0.1)),
          ..._installedModels.map((m) => _buildModelRow(m)),
        ],
      ],
    );
  }

  Widget _buildModelRow(ollama.ModelSummary model) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = model.name ?? 'unknown';
    final details = model.details;
    final paramSize = details?.parameterSize ?? '—';
    final quantLevel = details?.quantizationLevel ?? '—';
    final diskSize = model.size ?? 0;
    final fitness = _getModelFitness(model);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(paramSize, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            flex: 2,
            child: Text(quantLevel, style: theme.textTheme.bodySmall),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatBytes(diskSize),
              style: theme.textTheme.bodySmall,
            ),
          ),
          SizedBox(
            width: 80,
            child: _FitnessChip(fitness: fitness),
          ),
        ],
      ),
    );
  }

  // ---- 4. Benchmark Section -------------------------------------------------

  Widget _buildBenchmarkCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return _DiagCard(
      icon: Icons.speed_rounded,
      title: 'Performance Benchmark',
      accentColor: const Color(0xFFFF9800),
      trailing: _installedModels.isNotEmpty
          ? FilledButton.icon(
              onPressed: _benchmarking ? null : _runBenchmark,
              icon: _benchmarking
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(_benchmarking ? 'Running…' : 'Run Benchmark'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            )
          : null,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  size: 16, color: colors.onSurface.withOpacity(0.4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sends a fixed prompt to each model and measures tokens/sec.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_benchmarking && _benchmarkingModel != null) ...[
          const SizedBox(height: 16),
          _BenchmarkProgress(modelName: _benchmarkingModel!),
        ],

        if (_benchmarkResults.isNotEmpty) ...[
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Model',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.4),
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Tokens',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.4),
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Time',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.4),
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text('tok/s',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.4),
                      )),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.outlineVariant.withOpacity(0.1)),
          ..._benchmarkResults.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            final isBest = i == 0 && _benchmarkResults.length > 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        if (isBest)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(Icons.emoji_events_rounded,
                                size: 16, color: const Color(0xFFFFD700)),
                          ),
                        Flexible(
                          child: Text(
                            r.modelName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${r.tokenCount}',
                        style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text('${r.elapsedSeconds.toStringAsFixed(1)}s',
                        style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      r.tokensPerSecond.toStringAsFixed(1),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _benchmarkColor(r.tokensPerSecond),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Color _benchmarkColor(double tps) {
    if (tps >= 30) return const Color(0xFF4CAF50);
    if (tps >= 15) return const Color(0xFF8BC34A);
    if (tps >= 8) return const Color(0xFFFFEB3B);
    if (tps >= 3) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  // ---- 5. Model Recommendations ---------------------------------------------

  Widget _buildRecommendationsCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final vramGB = _bytesToGB(_estimatedVramBytes);
    final recommendations = _getRecommendations(vramGB);

    return _DiagCard(
      icon: Icons.recommend_rounded,
      title: 'Recommended Models',
      accentColor: const Color(0xFF00BCD4),
      children: [
        if (_estimatedVramBytes <= 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.help_outline_rounded,
                    size: 36, color: colors.onSurface.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text(
                  'VRAM not yet detected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Run a benchmark or load a model to detect your GPU memory, '
                  'then we can recommend models that will run well.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withOpacity(0.35),
                  ),
                ),
              ],
            ),
          )
        else ...[
          // VRAM tier banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00BCD4).withOpacity(0.12),
                  colors.primary.withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00BCD4).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.memory_rounded,
                    color: const Color(0xFF00BCD4), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Detected VRAM: ${_formatBytes(_estimatedVramBytes)}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFF00BCD4),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _getVramTierLabel(vramGB),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Recommendation list
          ...recommendations.map((rec) => _RecommendationTile(
                name: rec.name,
                description: rec.description,
                paramSize: rec.paramSize,
                fit: rec.fit,
                onDownload: () => Navigator.pushNamed(
                  context,
                  '/models/browse',
                ),
              )),
        ],
      ],
    );
  }

  String _getVramTierLabel(double vramGB) {
    if (vramGB >= 24) return 'High-end GPU — can run 70B+ models';
    if (vramGB >= 12) return 'Mid-high GPU — great for 27B–34B models';
    if (vramGB >= 8) return 'Mid-range GPU — good for 13B models';
    if (vramGB >= 6) return 'Entry-mid GPU — runs 7B-8B well';
    if (vramGB >= 4) return 'Entry GPU — best with 7B quantized models';
    return 'Low VRAM — stick to 1B–3B models';
  }

  List<_ModelRecommendation> _getRecommendations(double vramGB) {
    final recs = <_ModelRecommendation>[];

    if (vramGB >= 24) {
      recs.addAll([
        _ModelRecommendation(
          name: 'llama3.1:70b',
          description: 'Meta\'s flagship 70B model — exceptional reasoning',
          paramSize: '70B',
          fit: _RecommendFit.excellent,
        ),
        _ModelRecommendation(
          name: 'qwen2.5:32b',
          description: 'Alibaba\'s 32B model — strong coding & math',
          paramSize: '32B',
          fit: _RecommendFit.excellent,
        ),
        _ModelRecommendation(
          name: 'gemma3:27b',
          description: 'Google\'s 27B model — fast and capable',
          paramSize: '27B',
          fit: _RecommendFit.excellent,
        ),
      ]);
    }
    if (vramGB >= 12) {
      recs.addAll([
        _ModelRecommendation(
          name: 'gemma3:27b',
          description: 'Google\'s 27B — may need partial offload at 12GB',
          paramSize: '27B',
          fit: vramGB >= 24 ? _RecommendFit.excellent : _RecommendFit.good,
        ),
        _ModelRecommendation(
          name: 'qwen2.5:14b',
          description: 'Strong 14B model — excellent code generation',
          paramSize: '14B',
          fit: _RecommendFit.excellent,
        ),
        _ModelRecommendation(
          name: 'deepseek-coder-v2:16b',
          description: 'Specialized coding model — 16B MoE architecture',
          paramSize: '16B',
          fit: _RecommendFit.good,
        ),
      ]);
    }
    if (vramGB >= 6) {
      recs.addAll([
        _ModelRecommendation(
          name: 'llama3.2',
          description: 'Meta\'s 8B model — great all-rounder',
          paramSize: '8B',
          fit: _RecommendFit.excellent,
        ),
        _ModelRecommendation(
          name: 'gemma2',
          description: 'Google\'s efficient 9B model',
          paramSize: '9B',
          fit: _RecommendFit.excellent,
        ),
        _ModelRecommendation(
          name: 'mistral',
          description: 'Mistral 7B — fast and reliable',
          paramSize: '7B',
          fit: _RecommendFit.excellent,
        ),
      ]);
    }
    if (vramGB >= 4) {
      recs.addAll([
        _ModelRecommendation(
          name: 'phi3:mini',
          description: 'Microsoft\'s compact 3.8B — punches above its weight',
          paramSize: '3.8B',
          fit: _RecommendFit.excellent,
        ),
        _ModelRecommendation(
          name: 'llama3.2:3b',
          description: 'Meta\'s small 3B — good for constrained setups',
          paramSize: '3B',
          fit: _RecommendFit.excellent,
        ),
      ]);
    }
    if (vramGB < 4) {
      recs.addAll([
        _ModelRecommendation(
          name: 'llama3.2:1b',
          description: 'Ultra-light 1B — fast on any hardware',
          paramSize: '1B',
          fit: _RecommendFit.excellent,
        ),
        _ModelRecommendation(
          name: 'gemma2:2b',
          description: 'Google\'s tiny 2B — great quality for its size',
          paramSize: '2B',
          fit: _RecommendFit.excellent,
        ),
        _ModelRecommendation(
          name: 'phi3:mini',
          description: 'Microsoft 3.8B — may partially offload to CPU',
          paramSize: '3.8B',
          fit: _RecommendFit.okay,
        ),
      ]);
    }

    // Deduplicate by name, keep first occurrence
    final seen = <String>{};
    return recs.where((r) => seen.add(r.name)).toList();
  }
}

// =============================================================================
// Supporting widgets
// =============================================================================

/// A styled diagnostic card with gradient accent header.
class _DiagCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accentColor;
  final List<Widget> children;
  final Widget? trailing;

  const _DiagCard({
    required this.icon,
    required this.title,
    required this.accentColor,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accentColor.withOpacity(0.08),
                  Colors.transparent,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// A label-value row used inside diagnostic cards.
class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;

  const _InfoRow({required this.label, this.value, this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withOpacity(0.5),
            ),
          ),
          const Spacer(),
          child ??
              Text(
                value ?? '—',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
        ],
      ),
    );
  }
}

/// Loading indicator with shimmer effect.
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Running diagnostics…',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: colors.onSurface.withOpacity(0.5),
              ),
        ),
      ],
    );
  }
}

/// Benchmark progress indicator for a single model.
class _BenchmarkProgress extends StatelessWidget {
  final String modelName;
  const _BenchmarkProgress({required this.modelName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF9800).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: const Color(0xFFFF9800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Benchmarking $modelName…',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fitness chip showing how well a model fits available VRAM.
class _FitnessChip extends StatelessWidget {
  final _ModelFitness fitness;
  const _FitnessChip({required this.fitness});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (fitness) {
      _ModelFitness.fitsVram => ('GPU', const Color(0xFF4CAF50), Icons.check_circle_rounded),
      _ModelFitness.partialOffload => ('Partial', const Color(0xFFFF9800), Icons.warning_amber_rounded),
      _ModelFitness.cpuOnly => ('CPU', const Color(0xFFF44336), Icons.cancel_rounded),
      _ModelFitness.unknown => ('?', Colors.grey, Icons.help_outline_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single model recommendation tile.
class _RecommendationTile extends StatelessWidget {
  final String name;
  final String description;
  final String paramSize;
  final _RecommendFit fit;
  final VoidCallback onDownload;

  const _RecommendationTile({
    required this.name,
    required this.description,
    required this.paramSize,
    required this.fit,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final (fitLabel, fitColor) = switch (fit) {
      _RecommendFit.excellent => ('Excellent fit', const Color(0xFF4CAF50)),
      _RecommendFit.good => ('Good fit', const Color(0xFF8BC34A)),
      _RecommendFit.okay => ('May offload', const Color(0xFFFF9800)),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outlineVariant.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            // Model icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: fitColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.smart_toy_rounded, size: 20, color: fitColor),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          paramSize,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Fit badge + download
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: fitColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    fitLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: fitColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 28,
                  child: TextButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Get', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Enums & data classes
// =============================================================================

enum _ModelFitness { fitsVram, partialOffload, cpuOnly, unknown }

enum _RecommendFit { excellent, good, okay }

class _ModelRecommendation {
  final String name;
  final String description;
  final String paramSize;
  final _RecommendFit fit;

  const _ModelRecommendation({
    required this.name,
    required this.description,
    required this.paramSize,
    required this.fit,
  });
}
