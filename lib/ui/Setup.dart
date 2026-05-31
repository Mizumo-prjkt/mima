import 'package:flutter/material.dart';
import '../main.dart';
import '../store/store.dart';
import '../ollama/ollama_dart.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  final _urlController = TextEditingController(text: OllamaService.defaultServerUrl);
  bool _isTesting = false;
  _ConnectionStatus _status = _ConnectionStatus.idle;

  late final AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await MimaStore.instance.getSetting('server_url');
    if (url != null && mounted) {
      _urlController.text = url;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _status = _ConnectionStatus.testing;
    });

    final url = _urlController.text.trim();
    final success = await OllamaService.instance.testConnection(url);

    if (mounted) {
      setState(() {
        _isTesting = false;
        _status = success ? _ConnectionStatus.success : _ConnectionStatus.error;
      });
      if (success) {
        await MimaStore.instance.setSetting('server_url', url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 600;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? size.width * 0.1 : 24,
              vertical: 32,
            ),
            child: FadeTransition(
              opacity: CurvedAnimation(
                  parent: _entryCtrl, curve: Curves.easeOut),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- top bar ----
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/welcome'),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surfaceContainer,
                          ),
                        ),
                        const Spacer(),
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: themeNotifier,
                          builder: (context, currentMode, _) {
                            final isDark = currentMode == ThemeMode.dark;
                            return IconButton(
                              onPressed: () {
                                themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                              },
                              icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: colors.surfaceContainer,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ---- header ----
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.link_rounded,
                              color: colors.primary, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Connect to Ollama',
                                  style: theme.textTheme.headlineSmall),
                              const SizedBox(height: 4),
                              Text(
                                'Enter your Ollama server address',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),

                    // ---- URL input card ----
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Server URL',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                prefixIcon:
                                    const Icon(Icons.dns_rounded, size: 20),
                                hintText: 'http://your-server:11434',
                                suffixIcon: _buildStatusIcon(),
                              ),
                              onChanged: (_) {
                                if (_status != _ConnectionStatus.idle) {
                                  setState(
                                      () => _status = _ConnectionStatus.idle);
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Make sure Ollama is running on this address',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface.withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // test connection button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isTesting ? null : _testConnection,
                                icon: _isTesting
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colors.primary,
                                        ),
                                      )
                                    : Icon(_statusIcon),
                                label: Text(_statusLabel),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---- info card ----
                    Card(
                      color: colors.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: colors.onSurface.withOpacity(0.5),
                                size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Enter the IP address or hostname of your '
                                'Ollama server (e.g. 192.168.1.100:11434).\n\n'
                                'For Android devices, use your server\'s '
                                'LAN IP instead of localhost.\n'
                                'For Android Emulators, use 10.0.2.2 as the host.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurface.withOpacity(0.5),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // ---- continue button ----
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/main');
                        },
                        child: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget? _buildStatusIcon() {
    switch (_status) {
      case _ConnectionStatus.success:
        return const Icon(Icons.check_circle_rounded,
            color: Colors.greenAccent);
      case _ConnectionStatus.error:
        return Icon(Icons.error_rounded,
            color: Theme.of(context).colorScheme.error);
      default:
        return null;
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case _ConnectionStatus.success:
        return Icons.check_rounded;
      case _ConnectionStatus.error:
        return Icons.refresh_rounded;
      default:
        return Icons.wifi_tethering_rounded;
    }
  }

  String get _statusLabel {
    switch (_status) {
      case _ConnectionStatus.testing:
        return 'Testing…';
      case _ConnectionStatus.success:
        return 'Connected!';
      case _ConnectionStatus.error:
        return 'Retry';
      default:
        return 'Test Connection';
    }
  }
}

enum _ConnectionStatus { idle, testing, success, error }
