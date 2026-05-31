import 'package:flutter/foundation.dart';
import 'version.dart';

class MimaVersion {
  static String get versionId {
    if (kDebugMode) {
      final hash = kGitCommitHash.isEmpty ? 'unknown' : kGitCommitHash;
      final dirtySuffix = kGitDirty ? '-dirty' : '';
      return '$hash-debug$dirtySuffix';
    } else {
      // Release mode: determined by git tag
      final tag = kGitTag.trim();
      final tagPattern = RegExp(r'^v\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?$');
      final isValidTag = tag.isNotEmpty && tagPattern.hasMatch(tag);
      if (!isValidTag || kGitDirty) {
        // Tag mismatch, missing tag, or uncommitted files
        final baseTag = tag.isEmpty ? 'v0.0.0' : tag;
        return '$baseTag-dirty';
      }
      return tag;
    }
  }
}
