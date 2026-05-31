import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;

class TitleBar extends StatelessWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show the custom title bar on Windows and macOS.
    // Linux uses native window manager decorations (GTK/Plasma).
    if (!Platform.isWindows && !Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLowest, // Matches the app background
      child: SizedBox(
        height: 32,
        child: Row(
        children: [
          // Drag area
          Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Mima',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Window controls
          WindowCaptionButton(
            icon: Icons.minimize_rounded,
            onPressed: () => windowManager.minimize(),
            iconColor: colors.onSurface,
          ),
          WindowCaptionButton(
            icon: Icons.crop_square_rounded,
            onPressed: () async {
              if (await windowManager.isMaximized()) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            },
            iconColor: colors.onSurface,
          ),
          WindowCaptionButton(
            icon: Icons.close_rounded,
            onPressed: () => windowManager.close(),
            iconColor: colors.onSurface,
          ),
        ],
      ),
      ),
    );
  }
}

class WindowCaptionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color iconColor;
  final bool isClose;

  const WindowCaptionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.iconColor,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      hoverColor: isClose ? Colors.red : Colors.white.withValues(alpha: 0.1),
      child: Container(
        width: 46,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 14,
          color: iconColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
