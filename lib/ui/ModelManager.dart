// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:ollama_dart/ollama_dart.dart' as ollama;
import '../ollama/ollama_dart.dart';
import '../store/store.dart';
import '../widgets/Dialog.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  List<ollama.ModelSummary> _models = [];
  String? _defaultModelName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    final list = await OllamaService.instance.listModels();
    final defaultModel = await MimaStore.instance.getSetting('default_model');
    if (mounted) {
      setState(() {
        _models = list;
        // If default model name is not set or not in the list, set default to the first model if available
        if (defaultModel != null && list.any((m) => m.name == defaultModel)) {
          _defaultModelName = defaultModel;
        } else {
          _defaultModelName = list.isNotEmpty ? list[0].name : null;
          if (_defaultModelName != null) {
            MimaStore.instance.setSetting('default_model', _defaultModelName!);
          }
        }
        _isLoading = false;
      });
    }
  }

  void _deleteModel(ollama.ModelSummary model) async {
    final name = model.name ?? '';
    final size = model.size ?? 0;
    final confirm = await MimaDialog.confirm(
      context: context,
      title: 'Delete Model',
      message:
          'Are you sure you want to delete $name? This will free up ${_formatBytes(size)} of disk space.',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
      icon: Icons.delete_outline,
    );

    if (confirm) {
      final success = await OllamaService.instance.deleteModel(name);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$name deleted')));
        }
        _loadModels();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete $name')));
        }
      }
    }
  }

  void _setDefault(String name) async {
    await MimaStore.instance.setSetting('default_model', name);
    setState(() {
      _defaultModelName = name;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Default model set to $name')));
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final totalSpace = _models.fold<int>(0, (sum, m) => sum + (m.size ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloaded Models'),
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
                // Info header
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.sd_storage_outlined, color: colors.primary),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Total space used: ${_formatBytes(totalSpace)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/models/browse');
                          _loadModels();
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Get More'),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _models.isEmpty
                      ? Center(
                          child: Text(
                            'No models downloaded.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _models.length,
                          itemBuilder: (ctx, i) {
                            final model = _models[i];
                            final name = model.name ?? 'unknown';
                            final size = model.size ?? 0;
                            final isDefault = name == _defaultModelName;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.smart_toy_rounded,
                                  color: isDefault
                                      ? colors.primary
                                      : colors.onSurface.withValues(alpha: 0.5),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.primaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Default',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: colors.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(_formatBytes(size)),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (val) {
                                    if (val == 'default') _setDefault(name);
                                    if (val == 'delete') _deleteModel(model);
                                  },
                                  itemBuilder: (context) => [
                                    if (!isDefault)
                                      const PopupMenuItem(
                                        value: 'default',
                                        child: Text('Set as default'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text(
                                        'Delete model',
                                        style: TextStyle(color: Colors.red),
                                      ),
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
