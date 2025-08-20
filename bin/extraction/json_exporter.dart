// lib/src/extraction/json_exporter.dart
import 'dart:io';
import 'dart:convert';
import 'models.dart';

// lib/src/extraction/json_exporter.dart
import 'dart:io';
import 'dart:convert';
import 'models.dart';

class JsonExporter {
  static const String _langqDir = '.langq';
  static const String _extractedFile = 'extracted_strings.json';
  static const String _backupFile = 'extracted_strings.backup.json';
  static const String _pushMappingFile = 'push_mapping.json';
  static const String _historyDir = 'extraction_history';

  static Future<String> exportToJson(
    List<ExtractedString> strings, {
    String? projectPath,
  }) async {
    projectPath ??= Directory.current.path;

    // Create .langq directory structure
    await _ensureLangqDirectories(projectPath);

    final extractedPath = _getExtractedPath(projectPath);

    // Backup existing file if it exists
    await _backupExistingFile(projectPath);

    // Add unique IDs to strings for tracking
    final stringsWithIds = _addUniqueIds(strings);

    final exportData = {
      'metadata': {
        'extracted_at': DateTime.now().toIso8601String(),
        'total_strings': stringsWithIds.length,
        'with_placeholders':
            stringsWithIds.where((s) => s.hasPlaceholders).length,
        'without_placeholders':
            stringsWithIds.where((s) => !s.hasPlaceholders).length,
        'extraction_id': _generateExtractionId(),
      },
      'strings': stringsWithIds.map((s) => s.toJson()).toList(),
      'summary': _generateSummary(stringsWithIds),
    };

    final file = File(extractedPath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(exportData),
    );

    // Save to history
    await _saveToHistory(projectPath, exportData);

    print('📁 Extracted strings saved to: ${_relativePath(extractedPath)}');
    print('💾 Backup created: ${_relativePath(_getBackupPath(projectPath))}');

    return extractedPath;
  }

  static Future<void> _ensureLangqDirectories(String projectPath) async {
    final langqDir = Directory(_getLangqDir(projectPath));
    final historyDir = Directory(_getHistoryDir(projectPath));

    if (!await langqDir.exists()) {
      await langqDir.create();
      print('📁 Created .langq directory');
    }

    if (!await historyDir.exists()) {
      await historyDir.create();
      print('📁 Created extraction history directory');
    }

    // Update .gitignore
    await _updateGitignore(projectPath);
  }

  static Future<void> _updateGitignore(String projectPath) async {
    final gitignoreFile = File('$projectPath/.gitignore');

    if (await gitignoreFile.exists()) {
      final content = await gitignoreFile.readAsString();

      if (!content.contains('.langq/')) {
        await gitignoreFile.writeAsString(
          '$content\n# Lang Q working files\n.langq/\n',
          mode: FileMode.write,
        );
        print('📝 Added .langq/ to .gitignore');
      }
    }
    //  else {
    //   await gitignoreFile.writeAsString('# Lang Q working files\n.langq/\n');
    //   print('📝 Created .gitignore with .langq/ entry');
    // }
  }

  static Future<void> _backupExistingFile(String projectPath) async {
    final extractedFile = File(_getExtractedPath(projectPath));
    final backupFile = File(_getBackupPath(projectPath));

    if (await extractedFile.exists()) {
      await extractedFile.copy(backupFile.path);
    }
  }

  static Future<void> _saveToHistory(
    String projectPath,
    Map<String, dynamic> data,
  ) async {
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
    final historyFile = File('${_getHistoryDir(projectPath)}/$timestamp.json');

    await historyFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
    );
  }

  static List<ExtractedString> _addUniqueIds(List<ExtractedString> strings) {
    return strings.map((string) {
      string.id = _generateStringId(string);
      return string;
    }).toList();
  }

  static String _generateStringId(ExtractedString string) {
    // Generate a unique ID based on content and location
    final content =
        '${string.value}|${string.filePath}|${string.line}|${string.column}';
    return content.hashCode.abs().toString();
  }

  static String _generateExtractionId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  static Map<String, dynamic> _generateSummary(List<ExtractedString> strings) {
    final contextCounts = <String, int>{};
    final fileCounts = <String, int>{};
    final placeholderCounts = <String, int>{};

    for (final string in strings) {
      contextCounts[string.parentContext] =
          (contextCounts[string.parentContext] ?? 0) + 1;

      final fileName = string.filePath.split('/').last;
      fileCounts[fileName] = (fileCounts[fileName] ?? 0) + 1;

      for (final placeholder in string.placeholders) {
        placeholderCounts[placeholder] =
            (placeholderCounts[placeholder] ?? 0) + 1;
      }
    }

    return {
      'by_context': contextCounts,
      'by_file': fileCounts,
      'common_placeholders': placeholderCounts,
    };
  }

  // Helper methods for paths
  static String _getLangqDir(String projectPath) => '$projectPath/$_langqDir';
  static String _getHistoryDir(String projectPath) =>
      '${_getLangqDir(projectPath)}/$_historyDir';
  static String _getExtractedPath(String projectPath) =>
      '${_getLangqDir(projectPath)}/$_extractedFile';
  static String _getBackupPath(String projectPath) =>
      '${_getLangqDir(projectPath)}/$_backupFile';
  static String _getPushMappingPath(String projectPath) =>
      '${_getLangqDir(projectPath)}/$_pushMappingFile';

  static String _relativePath(String fullPath) {
    final currentDir = Directory.current.path;
    return fullPath.replaceFirst('$currentDir/', '');
  }

  // Public method to get paths for other commands
  static String getExtractedPath([String? projectPath]) {
    projectPath ??= Directory.current.path;
    return _getExtractedPath(projectPath);
  }

  static String getPushMappingPath([String? projectPath]) {
    projectPath ??= Directory.current.path;
    return _getPushMappingPath(projectPath);
  }
}
