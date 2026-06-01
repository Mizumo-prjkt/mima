import 'package:flutter/material.dart';
import '../store/store.dart';

class SplashBootScreen extends StatefulWidget {
  const SplashBootScreen({super.key});

  @override
  State<SplashBootScreen> createState() => _SplashBootScreenState();
}

class _SplashBootScreenState extends State<SplashBootScreen> {
  @override
  void initState() {
    super.initState();
    _checkSetupAndNavigate();
  }

  Future<void> _checkSetupAndNavigate() async {
    try {
      final url = await MimaStore.instance.getSetting('server_url');
      if (!mounted) return;
      if (url != null) {
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        Navigator.pushReplacementNamed(context, '/welcome');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: colors.primary,
          ),
        ),
      ),
    );
  }
}