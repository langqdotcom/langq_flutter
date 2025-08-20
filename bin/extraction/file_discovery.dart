// lib/src/extraction/file_discovery.dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'extraction_config.dart';

class FileDiscovery {
  final ExtractionConfig config;

  FileDiscovery(this.config);

  Future<List<File>> getTargetFiles(String projectPath) async {
    final libDir = Directory(path.join(projectPath, 'lib'));
    if (!await libDir.exists()) {
      throw Exception('lib directory not found in $projectPath');
    }

    final allFiles = <File>[];

    // Recursively find all .dart files in lib/
    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final relativePath = path.relative(entity.path, from: projectPath);

        if (!_shouldExcludeFile(relativePath)) {
          allFiles.add(entity);
        }
      }
    }

    return allFiles;
  }

  bool _shouldExcludeFile(String relativePath) {
    // FIX: Use config.exclude, not config.ignoreWords
    for (final pattern in config.exclude) {
      if (_matchesPattern(relativePath, pattern)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesPattern(String filePath, String pattern) {
    if (pattern.contains('**')) {
      final regexPattern = pattern
          .replaceAll('**/', '.*/')
          .replaceAll('*', '[^/]*')
          .replaceAll('.', r'\.');

      try {
        return RegExp('^$regexPattern\$').hasMatch(filePath);
      } catch (e) {
        print('⚠️  Invalid pattern: $pattern');
        return false;
      }
    } else if (pattern.contains('*')) {
      final regexPattern = pattern.replaceAll('*', '.*').replaceAll('.', r'\.');

      try {
        return RegExp(regexPattern).hasMatch(filePath);
      } catch (e) {
        return false;
      }
    } else {
      return filePath == pattern || filePath.contains(pattern);
    }
  }
}
