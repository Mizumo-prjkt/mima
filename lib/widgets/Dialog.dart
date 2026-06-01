import 'package:flutter/material.dart';
import 'dart:ui';

/// A premium glassmorphic dialog with blur backdrop and scale+fade animation.
///
/// Use [MimaDialog.show] for a general-purpose dialog or
/// [MimaDialog.confirm] for quick yes/no confirmations.
class MimaDialog extends StatelessWidget {
  final String? title;
  final Widget? content;
  final List<Widget>? actions;
  final IconData? icon;
  final Color? iconColor;
  final bool showCloseButton;
  final double maxWidth;

  const MimaDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.icon,
    this.iconColor,
    this.showCloseButton = true,
    this.maxWidth = 420,
  });

  // ---------------------------------------------------------------------------
  // Static helpers
  // ---------------------------------------------------------------------------

  /// Show the dialog with scale+fade+blur transition.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    Widget? content,
    List<Widget>? actions,
    IconData? icon,
    Color? iconColor,
    bool showCloseButton = true,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'MimaDialog',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, _, _) => MimaDialog(
        title: title,
        content: content,
        actions: actions,
        icon: icon,
        iconColor: iconColor,
        showCloseButton: showCloseButton,
      ),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 6 * animation.value,
            sigmaY: 6 * animation.value,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          ),
        );
      },
    );
  }

  /// Convenience confirmation dialog. Returns `true` when confirmed.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    IconData? icon,
    Color? iconColor,
  }) async {
    final result = await show<bool>(
      context: context,
      title: title,
      icon: icon,
      iconColor: iconColor,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelText),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: confirmColor != null
              ? FilledButton.styleFrom(backgroundColor: confirmColor)
              : null,
          child: Text(confirmText),
        ),
      ],
    );
    return result ?? false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Material(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.2),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.surfaceContainer,
                    colors.surfaceContainerHigh.withValues(alpha: 0.6),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ---- header ------------------------------------------------
                  if (icon != null || title != null || showCloseButton) ...[
                    Row(
                      children: [
                        if (icon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (iconColor ?? colors.primary).withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: iconColor ?? colors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        if (title != null)
                          Expanded(
                            child: Text(
                              title!,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                        if (showCloseButton)
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: colors.surfaceContainerHighest,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ---- body -------------------------------------------------
                  ?content,

                  // ---- actions ----------------------------------------------
                  if (actions != null && actions!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (int i = 0; i < actions!.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          actions![i],
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
