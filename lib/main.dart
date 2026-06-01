import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform, exit, File;
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'store/store.dart';

import 'ui/SplashBoot.dart';
import 'ui/Welcome.dart';
import 'ui/Setup.dart';
import 'ui/MainMenu.dart';
import 'ui/Chat.dart';
import 'ui/Settings.dart';
import 'ui/FilePicker.dart' as fp;
import 'ui/Preview.dart';
import 'ui/ModelBrowser.dart';
import 'ui/ModelManager.dart';
import 'ui/About.dart';
import 'ui/HardwareDiagnostics.dart';
import 'widgets/TitleBar.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (args.isNotEmpty) {
    await _handleCommandLineArgs(args);
  }
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A14),
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    
    WindowOptions windowOptions = WindowOptions(
      size: const Size(1100, 750),
      minimumSize: const Size(400, 600),
      center: true,
      backgroundColor: Colors.transparent,
      // Hide title bar only on Windows and macOS. Linux DEs (GTK/Plasma) expect native SSDs.
      titleBarStyle: Platform.isLinux ? TitleBarStyle.normal : TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const MimaApp());
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> _handleCommandLineArgs(List<String> args) async {
  bool handled = false;

  if (args.contains('--reset-all')) {
    // Delete database file in support directory
    try {
      final supportDir = await getApplicationSupportDirectory();
      final supportFile = File(p.join(supportDir.path, 'mima.db'));
      if (await supportFile.exists()) {
        await supportFile.delete();
      }
    } catch (_) {}

    // Delete database file in documents directory
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final docsFile = File(p.join(docsDir.path, 'mima.db'));
      if (await docsFile.exists()) {
        await docsFile.delete();
      }
    } catch (_) {}

    print('[Mima] Purged all database and settings files.');
    handled = true;
  } else if (args.contains('--reset-app')) {
    try {
      await MimaStore.instance.clearAppSettings();
      print('[Mima] Cleared all app settings.');
    } catch (e) {
      print('[Mima] Failed to clear app settings: $e');
    }
    handled = true;
  } else if (args.contains('--reset-db')) {
    try {
      await MimaStore.instance.clearChatDatabase();
      print('[Mima] Cleared all chat sessions and messages.');
    } catch (e) {
      print('[Mima] Failed to clear chat database: $e');
    }
    handled = true;
  }

  if (handled) {
    exit(0);
  }
}

class MimaApp extends StatelessWidget {
  const MimaApp({super.key});

  static const Color _seedColor = Color(0xFF7C4DFF);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Mima',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          darkTheme: _buildDarkTheme(),
          theme: _buildLightTheme(),
          initialRoute: '/splash',
          onGenerateRoute: _onGenerateRoute,
          builder: (context, child) {
            return Column(
              children: [
                const TitleBar(),
                Expanded(
                  child: ClipRect(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    Widget page;
    switch (settings.name) {
      case '/welcome':
        page = const WelcomeScreen();
      case '/setup':
        page = const SetupScreen();
      case '/main':
        page = const MainMenuScreen();
      case '/chat':
        page = ChatScreen(chatId: settings.arguments as String?);
      case '/settings':
        page = const SettingsScreen();
      case '/filepicker':
        page = const fp.FilePickerScreen();
      case '/preview':
        page = PreviewScreen(data: settings.arguments as PreviewData?);
      case '/models/browse':
        page = const ModelBrowserScreen();
      case '/models/manage':
        page = const ModelManagerScreen();
      case '/about':
        page = const AboutScreen();
      case '/diagnostics':
        page = const HardwareDiagnosticsScreen();
      case '/splash':
        page = const SplashBootScreen();
      default:
        page = const WelcomeScreen();
    }
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF0E0E1B),
      surfaceContainerLowest: const Color(0xFF0A0A14),
      surfaceContainerLow: const Color(0xFF121220),
      surfaceContainer: const Color(0xFF1A1A2E),
      surfaceContainerHigh: const Color(0xFF222236),
      surfaceContainerHighest: const Color(0xFF2A2A3E),
    );
    return _buildThemeData(colorScheme, Brightness.dark);
  }

  static ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return _buildThemeData(colorScheme, Brightness.light);
  }

  static ThemeData _buildThemeData(ColorScheme colorScheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,

      // Card
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        color: colorScheme.surfaceContainer,
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        hintStyle: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),

      // Buttons
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            inherit: false,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.15),
        thickness: 1,
        space: 1,
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: colorScheme.onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
      ),

      // PopupMenu
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withValues(alpha: 0.3);
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
      ),

      // Chip
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Text
      textTheme: const TextTheme(
        displayLarge:
            TextStyle(fontWeight: FontWeight.w300, letterSpacing: -1.5),
        displayMedium:
            TextStyle(fontWeight: FontWeight.w300, letterSpacing: -0.5),
        displaySmall:
            TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0),
        headlineLarge:
            TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.5),
        headlineMedium:
            TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.3),
        headlineSmall:
            TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0),
        titleLarge:
            TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0),
        titleMedium:
            TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.15),
        titleSmall:
            TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.1),
        bodyLarge: TextStyle(
            fontWeight: FontWeight.w400, letterSpacing: 0.15, height: 1.5),
        bodyMedium: TextStyle(
            fontWeight: FontWeight.w400, letterSpacing: 0.25, height: 1.5),
        bodySmall:
            TextStyle(fontWeight: FontWeight.w400, letterSpacing: 0.4),
        labelLarge:
            TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        labelMedium:
            TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
        labelSmall:
            TextStyle(fontWeight: FontWeight.w500, letterSpacing: 0.5),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Responsive breakpoint utilities
// ---------------------------------------------------------------------------
class MimaBreakpoints {
  MimaBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobile;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobile && w < desktop;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;

  /// True when the screen is wide enough for a sidebar layout.
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;
}
