import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../store/store.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _entryCtrl;
  late final Animation<double> _pulse;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();

    // Continuous pulsing glow on the logo
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.92, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // One-shot entry animation
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFirstLaunch() async {
    try {
      final url = await MimaStore.instance.getSetting('server_url');
      if (url != null && mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      // Ignore DB errors on startup
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.4,
            colors: [
              colors.primary.withOpacity(0.07),
              colors.surface,
              colors.surfaceContainerLowest,
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? size.width * 0.15 : 40,
                vertical: 40,
              ),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ---------- animated logo ----------
                      ScaleTransition(
                        scale: _pulse,
                        child: Container(
                          width: isLandscape ? 100 : 120,
                          height: isLandscape ? 100 : 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [colors.primary, colors.tertiary],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withOpacity(0.35),
                                blurRadius: 48,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: isLandscape ? 46 : 54,
                            color: colors.onPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: isLandscape ? 28 : 44),

                      // ---------- gradient app name ----------
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [colors.primary, colors.tertiary],
                        ).createShader(bounds),
                        child: Text(
                          'Mima',
                          style: theme.textTheme.displayMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ---------- tagline ----------
                      Text(
                        'Your local AI companion',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onSurface.withOpacity(0.55),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: isLandscape ? 36 : 56),

                      // ---------- CTA ----------
                      SizedBox(
                        width: math.min(size.width * 0.7, 320),
                        height: 56,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pushReplacementNamed(context, '/setup');
                          },
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Get Started',
                                  style: TextStyle(fontSize: 17)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ---------- footer ----------
                      Text(
                        'Powered by Ollama',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
