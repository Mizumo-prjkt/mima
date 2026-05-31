import 'package:flutter/material.dart';

class FilePickerScreen extends StatefulWidget {
  // In a real implementation, you'd pass the developer settings flag here
  final bool allowImages;
  const FilePickerScreen({super.key, this.allowImages = false});

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  // Mock selected files
  final List<String> _selectedFiles = [];

  void _pickFile() {
    // Mock file picking logic
    setState(() {
      _selectedFiles.add('system_logs_2025.txt');
    });
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isWide = MediaQuery.sizeOf(context).width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attach Files'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        actions: [
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.tonal(
                onPressed: () {
                  // return files to ChatScreen
                  Navigator.pop(context, _selectedFiles);
                },
                child: Text('Add ${_selectedFiles.length} file(s)'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- drop zone ----
                  InkWell(
                    onTap: _pickFile,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: isWide ? 200 : 160,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.outlineVariant.withOpacity(0.5),
                          width: 2,
                          style: BorderStyle.solid, // Use solid for now as dashed requires custom painter or a package
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 48,
                            color: colors.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isWide
                                ? 'Drag & drop files here, or click to browse'
                                : 'Tap to browse files',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.allowImages
                                ? 'Supported: TXT, MD, CSV, JSON, PNG, JPG'
                                : 'Supported: TXT, MD, CSV, JSON',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ---- selected files list ----
                  if (_selectedFiles.isNotEmpty) ...[
                    Text(
                      'Selected Files',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _selectedFiles.length,
                        itemBuilder: (ctx, i) {
                          final file = _selectedFiles[i];
                          final isImage =
                              file.endsWith('.png') || file.endsWith('.jpg');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                isImage
                                    ? Icons.image_rounded
                                    : Icons.description_rounded,
                                color: colors.primary,
                              ),
                              title: Text(file),
                              subtitle: const Text('14 KB'),
                              trailing: IconButton(
                                icon: Icon(Icons.remove_circle_outline,
                                    color: colors.error),
                                onPressed: () => _removeFile(i),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                    Center(
                      child: Text(
                        'No files selected',
                        style: TextStyle(
                            color: colors.onSurface.withOpacity(0.3)),
                      ),
                    ),
                    const Spacer(),
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
