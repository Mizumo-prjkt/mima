import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../versioning/versioning_aware.dart';

/// Data class for a third-party package displayed in the About screen.
class _PackageInfo {
  final String name;
  final String version;
  final String description;
  final String license;
  final String url;

  const _PackageInfo({
    required this.name,
    required this.version,
    required this.description,
    required this.license,
    required this.url,
  });
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _fade;

  // Direct dependencies declared in pubspec.yaml
  static const List<_PackageInfo> _packages = [
    _PackageInfo(
      name: 'ollama_dart',
      version: '2.2.0',
      description:
          'Dart client for the Ollama API. Generate embeddings, completions, and manage models.',
      license: 'MIT',
      url: 'https://pub.dev/packages/ollama_dart',
    ),
    _PackageInfo(
      name: 'drift',
      version: '2.33.0',
      description:
          'A reactive persistence library for Dart and Flutter, built on top of SQLite.',
      license: 'MIT',
      url: 'https://pub.dev/packages/drift',
    ),
    _PackageInfo(
      name: 'window_manager',
      version: '0.5.1',
      description:
          'A Flutter plugin for resizing, repositioning, and managing desktop windows.',
      license: 'MIT',
      url: 'https://pub.dev/packages/window_manager',
    ),
    _PackageInfo(
      name: 'cupertino_icons',
      version: '1.0.8',
      description:
          'Default set of Cupertino (iOS-style) icons used by Flutter\'s Cupertino widgets.',
      license: 'MIT',
      url: 'https://pub.dev/packages/cupertino_icons',
    ),
    _PackageInfo(
      name: 'material',
      version: '1.0.1',
      description:
          'Material Design utilities and helpers for Flutter applications.',
      license: 'BSD-3-Clause',
      url: 'https://pub.dev/packages/material',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isWide = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
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
                  // ──────────── App Identity ────────────
                  _buildAppHeader(theme, colors),
                  const SizedBox(height: 32),

                  // ──────────── Open-Source Packages ────────────
                  _SectionHeader(
                    title: 'Open-Source Packages',
                    icon: Icons.inventory_2_outlined,
                  ),
                  _AboutCard(
                    child: Column(
                      children: [
                        for (int i = 0; i < _packages.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _PackageTile(pkg: _packages[i]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ──────────── License Disclaimer ────────────
                  _SectionHeader(
                    title: 'License & Disclaimer',
                    icon: Icons.gavel_rounded,
                  ),
                  _AboutCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.tertiary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.shield_outlined,
                                    color: colors.tertiary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Software License Notice',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'This application is built with Flutter and makes use of '
                            'several open-source packages distributed via pub.dev. '
                            'Each package is subject to its own license terms as listed above.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface.withOpacity(0.75),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, '
                            'EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES '
                            'OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND '
                            'NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT '
                            'HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withOpacity(0.5),
                              height: 1.6,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Mima communicates exclusively with a locally-hosted Ollama '
                            'server. No data is sent to external services. '
                            'All conversations stay on your machine.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurface.withOpacity(0.75),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ──────────── Flutter & Dart Runtime ────────────
                  _SectionHeader(
                    title: 'Runtime',
                    icon: Icons.memory_rounded,
                  ),
                  _AboutCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF027DFD).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.flutter_dash_rounded,
                                color: Color(0xFF027DFD), size: 20),
                          ),
                          title: const Text('Flutter'),
                          subtitle: const Text('UI toolkit by Google'),
                          trailing: Chip(
                            label: Text('SDK',
                                style: theme.textTheme.labelSmall),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0175C2).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.code_rounded,
                                color: Color(0xFF0175C2), size: 20),
                          ),
                          title: const Text('Dart'),
                          subtitle: const Text('Programming language'),
                          trailing: Chip(
                            label: Text('SDK ≥ 3.12',
                                style: theme.textTheme.labelSmall),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ──────────── View All Licenses (Flutter built-in) ────────────
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showLicensePage(
                          context: context,
                          applicationName: 'Mima',
                          applicationVersion: MimaVersion.versionId,
                          applicationIcon: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [colors.primary, colors.tertiary],
                                ),
                              ),
                              child: Icon(Icons.auto_awesome_rounded,
                                  size: 28, color: colors.onPrimary),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('View All Licenses'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppHeader(ThemeData theme, ColorScheme colors) {
    return Center(
      child: Column(
        children: [
          // Gradient logo
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primary, colors.tertiary],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.25),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 38, color: colors.onPrimary),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [colors.primary, colors.tertiary],
            ).createShader(bounds),
            child: Text(
              'Mima',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              MimaVersion.versionId,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your local AI companion · Powered by Ollama',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helper widgets (mirrors Settings.dart patterns)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

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
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final Widget child;
  const _AboutCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _PackageTile extends StatelessWidget {
  final _PackageInfo pkg;
  const _PackageTile({required this.pkg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            pkg.name.substring(0, 1).toUpperCase(),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(pkg.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              pkg.version,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          pkg.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface.withOpacity(0.55),
          ),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.tertiary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          pkg.license,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.tertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
