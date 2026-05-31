import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final supportDir = await getApplicationSupportDirectory();
    // Ensure parent directories exist
    await supportDir.create(recursive: true);
    final targetFile = File(p.join(supportDir.path, 'mima.db'));

    // Migrate from the old documents directory location if it exists
    try {
      final oldDir = await getApplicationDocumentsDirectory();
      final oldFile = File(p.join(oldDir.path, 'mima.db'));
      if (await oldFile.exists() && !await targetFile.exists()) {
        await oldFile.copy(targetFile.path);
        await oldFile.delete();
      }
    } catch (e) {
      // Silently ignore migration errors to ensure the app still starts
    }

    return NativeDatabase.createInBackground(targetFile);
  });
}
