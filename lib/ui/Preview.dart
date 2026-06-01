import 'package:flutter/material.dart';

// Helper class to pass data to the preview screen
class PreviewData {
  final String title;
  final String? textContent; // For text files
  final String? imagePath; // For images (mocked as string for now)

  PreviewData({required this.title, this.textContent, this.imagePath});
}

class PreviewScreen extends StatelessWidget {
  final PreviewData? data;

  const PreviewScreen({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isImage = data?.imagePath != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        title: Text(data?.title ?? 'Preview'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white),
            onPressed: () {
              // Handle share
            },
          ),
          if (!isImage)
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: Colors.white),
              onPressed: () {
                // Handle copy text
              },
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Center(
          child: isImage
              ? _buildImagePreview(colors)
              : _buildTextPreview(theme, colors),
        ),
      ),
    );
  }

  Widget _buildImagePreview(ColorScheme colors) {
    // In a real app, use InteractiveViewer and Image.file / Image.network
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 120, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'Image Preview\n${data?.imagePath}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextPreview(ThemeData theme, ColorScheme colors) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: colors.surfaceContainerLowest,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Text(
          data?.textContent ?? 'No content available.',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
