import 'package:flutter/material.dart';
import '../widgets/Dialog.dart';
import '../main.dart';
import '../versioning/versioning_aware.dart';
import '../store/store.dart';
import '../ollama/ollama_dart.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Settings state
  double _fontSize = 14.0;
  bool _enableDeveloperSettings = false;
  bool _enableImageAttachments = false;
  String _serverUrl = OllamaService.defaultServerUrl;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final url = await MimaStore.instance.getSetting('server_url');
    if (url != null && mounted) {
      setState(() {
        _serverUrl = url;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isWide = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 32 : 16,
                vertical: 24,
              ),
              children: [
                // ---- connection section ----
                _SectionHeader(title: 'Connection', icon: Icons.wifi_tethering),
                _SettingsCard(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.dns_outlined, color: Colors.grey),
                      title: const Text('Ollama Server URL'),
                      subtitle: Text(_serverUrl),
                      trailing: const Icon(Icons.edit_rounded, size: 18),
                      onTap: () {
                        final editController =
                            TextEditingController(text: _serverUrl);
                        MimaDialog.show(
                          context: context,
                          title: 'Edit Server URL',
                          content: TextField(
                            controller: editController,
                            decoration: const InputDecoration(
                                hintText: 'http://your-server:11434'),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () async {
                                  final newUrl = editController.text.trim();
                                  if (newUrl.isNotEmpty) {
                                    await MimaStore.instance
                                        .setSetting('server_url', newUrl);
                                    if (mounted) {
                                      setState(() {
                                        _serverUrl = newUrl;
                                      });
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content:
                                                Text('Server URL updated')),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Save')),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ---- appearance section ----
                _SectionHeader(title: 'Appearance', icon: Icons.palette_outlined),
                _SettingsCard(
                  children: [
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, currentMode, _) {
                        return SwitchListTile(
                          secondary: const Icon(Icons.dark_mode_outlined, color: Colors.grey),
                          title: const Text('Dark Mode'),
                          value: currentMode == ThemeMode.dark,
                          onChanged: (v) {
                            themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                          },
                        );
                      },
                    ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Text Size', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.text_fields, size: 16),
                              Expanded(
                                child: Slider(
                                  value: _fontSize,
                                  min: 12,
                                  max: 24,
                                  divisions: 6,
                                  label: _fontSize.round().toString(),
                                  onChanged: (v) =>
                                      setState(() => _fontSize = v),
                                ),
                              ),
                              const Icon(Icons.text_fields, size: 24),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ---- data section ----
                _SectionHeader(title: 'Data & Storage', icon: Icons.storage_outlined),
                _SettingsCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.upload_file_outlined,
                          color: Colors.grey),
                      title: const Text('Import Chats'),
                      subtitle: const Text('Restore from backup file'),
                      onTap: () {
                        // logic to import
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.download_rounded,
                          color: Colors.grey),
                      title: const Text('Export Chats'),
                      subtitle: const Text('Save all chats to a backup file'),
                      onTap: () {
                        // logic to export
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: Icon(Icons.delete_sweep_outlined,
                          color: colors.error),
                      title: Text('Clear All Data',
                          style: TextStyle(color: colors.error)),
                      subtitle: const Text('Delete all chats and settings'),
                      onTap: () async {
                        final confirm = await MimaDialog.confirm(
                          context: context,
                          title: 'Clear All Data',
                          message:
                              'Are you sure you want to delete all chats? This cannot be undone.',
                          confirmText: 'Delete',
                          confirmColor: colors.error,
                          icon: Icons.warning_amber_rounded,
                          iconColor: colors.error,
                        );
                        if (confirm && mounted) {
                          await MimaStore.instance.clearAllData();
                          setState(() {
                            _serverUrl = OllamaService.defaultServerUrl;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('All data cleared successfully')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ---- developer settings section ----
                _SectionHeader(
                  title: 'Developer',
                  icon: Icons.developer_mode,
                  trailing: Switch(
                    value: _enableDeveloperSettings,
                    onChanged: (v) =>
                        setState(() => _enableDeveloperSettings = v),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: _SettingsCard(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.image_outlined,
                            color: Colors.grey),
                        title: const Text('Enable Image Attachments'),
                        subtitle: const Text(
                            'Allow picking images for multimodal models like llava'),
                        value: _enableImageAttachments,
                        onChanged: (v) =>
                            setState(() => _enableImageAttachments = v),
                      ),
                    ],
                  ),
                  crossFadeState: _enableDeveloperSettings
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
                const SizedBox(height: 32),

                // ---- about ----
                _SectionHeader(title: 'About', icon: Icons.info_outline_rounded),
                _SettingsCard(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome_rounded,
                            color: colors.primary, size: 20),
                      ),
                      title: Text('Mima ${MimaVersion.versionId}'),
                      subtitle: Text('Built with Flutter',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withOpacity(0.5))),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pushNamed(context, '/about'),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({required this.title, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12, right: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }
}
