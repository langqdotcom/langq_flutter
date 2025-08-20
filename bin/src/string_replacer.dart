// lib/src/replacement/code_replacer.dart
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package_info.dart';

class CodeReplacer {
  final Map<String, ExtractionData> extractionData;
  final Set<String> processedFiles = {};

  CodeReplacer(this.extractionData);

  Future<void> replaceAllStrings() async {
    // Group by file to handle multiple replacements per file
    final fileGroups = _groupByFile();

    for (final entry in fileGroups.entries) {
      final filePath = entry.key;
      final extractions = entry.value;

      await _replaceInFile(filePath, extractions);
    }

    print('✅ Replaced strings in ${processedFiles.length} files');
  }

  Map<String, List<ExtractionData>> _groupByFile() {
    final groups = <String, List<ExtractionData>>{};

    for (final extraction in extractionData.values) {
      groups.putIfAbsent(extraction.filePath, () => []).add(extraction);
    }

    // Sort by start_offset DESC to replace from end to start (avoids offset shifts)
    for (final extractions in groups.values) {
      extractions.sort((a, b) => b.startOffset.compareTo(a.startOffset));
    }

    return groups;
  }

  Future<void> _replaceInFile(
    String filePath,
    List<ExtractionData> extractions,
  ) async {
    final file = File(filePath);

    if (!await file.exists()) {
      print('⚠️  File not found: $filePath');
      return;
    }

    try {
      String content = await file.readAsString();
      bool hasChanges = false;
      bool needsImport = false;
      final stats = ReplacementStats();

      // Replace from end to start to preserve offsets
      for (final extraction in extractions) {
        final result = _performReplacement(content, extraction);

        switch (result.status) {
          case ReplacementStatus.success:
            content = result.newContent;
            hasChanges = true;
            needsImport = true;
            stats.success++;
            print(
              '✨ Replaced: "${_truncateString(extraction.originalRawValue)}" -> ${result.replacement}',
            );
            break;

          case ReplacementStatus.alreadyReplaced:
            stats.alreadyReplaced++;
            print('✅ Already replaced: ${result.replacement}');
            break;

          case ReplacementStatus.ambiguous:
            stats.ambiguous++;
            print('🔄 Ambiguous: ${result.error}');
            break;

          case ReplacementStatus.failed:
            stats.failed++;
            print('❌ Failed: ${result.error}');
            break;
        }

        // if (result.success) {
        //   content = result.newContent;
        //   hasChanges = true;
        //   needsImport = true;
        //   print(
        //     '✨ Replaced: "${extraction.originalRawValue}" -> ${result.replacement}',
        //   );
        // } else {
        //   print(
        //     '❌ Failed to replace at ${path.basename(filePath)}:${extraction.line}',
        //   );
        //   print('   Reason: ${result.error}');
        // }
      }

      // Add import if needed
      if (needsImport) {
        content = await _addImportIfNeeded(content);
      }

      if (hasChanges) {
        await file.writeAsString(content);
        processedFiles.add(filePath);
        print('📝 Updated: ${path.basename(filePath)}');
      }

      // Summary for this file
      final fileName = path.basename(filePath);
      print('📁 $fileName: ${stats.getSummary()}');
    } catch (e) {
      print('❌ Error processing $filePath: $e');
    }
  }

  ReplacementResult _performReplacement(
    String content,
    ExtractionData extraction,
  ) {
    // Validate offsets
    if (extraction.startOffset < 0 ||
        extraction.endOffset > content.length ||
        extraction.startOffset >= extraction.endOffset) {
      return ReplacementResult.failure('Invalid offsets');
    }

    // Extract the actual string from file
    final actualString = content.substring(
      extraction.startOffset,
      extraction.endOffset,
    );

    if (actualString == extraction.originalRawValue) {
      // Perfect match - do the replacement
      final replacement = _buildReplacement(extraction);
      final before = content.substring(0, extraction.startOffset);
      final after = content.substring(extraction.endOffset);
      final newContent = before + replacement + after;

      return ReplacementResult.success(newContent, replacement);
    }

    // Step 2: Offset failed - check if already replaced
    return _checkIfAlreadyReplaced(content, extraction);
  }

  ReplacementResult _checkIfAlreadyReplaced(
    String content,
    ExtractionData extraction,
  ) {
    final functionName = _generateFunctionName(extraction.langqKey);
    final expectedFunction = 'LangQKey.$functionName';

    // Step 2a: Check if LangQKey.functionName exists in the file
    final hasLangQFunction = content.contains(expectedFunction);

    print('check: ${expectedFunction} == ${extraction.originalRawValue}');

    // Step 2b: Check if the exact extracted string exists anywhere in the file
    final hasOriginalString = content.contains(extraction.originalRawValue);

    if (hasLangQFunction && !hasOriginalString) {
      // High confidence: function exists, original string doesn't = already replaced
      return ReplacementResult.alreadyReplaced(
        '$expectedFunction (detected in file)',
      );
    }

    if (hasLangQFunction && hasOriginalString) {
      // Ambiguous: both exist - could be partial replacement or multiple occurrences
      return ReplacementResult.ambiguous(
        'Both $expectedFunction and original string found in file. Manual check needed.',
      );
    }

    if (!hasLangQFunction && !hasOriginalString) {
      // Neither exists - file changed significantly
      return ReplacementResult.failure(
        'Neither function nor original string found. File may have been modified significantly.',
      );
    }

    // hasOriginalString && !hasLangQFunction
    // String exists but function doesn't - try to find and replace it
    return _tryContentBasedReplacement(content, extraction);
  }

  ReplacementResult _tryContentBasedReplacement(
    String content,
    ExtractionData extraction,
  ) {
    // Find the string in the content
    final stringIndex = content.indexOf(extraction.originalRawValue);

    if (stringIndex == -1) {
      return ReplacementResult.failure(
        'String not found despite contains() check. Encoding issue?',
      );
    }

    // Check if there are multiple occurrences
    final lastIndex = content.lastIndexOf(extraction.originalRawValue);
    if (stringIndex != lastIndex) {
      // Multiple occurrences - be more careful
      final lineHint = extraction.line;
      final foundIndex = _findStringNearLine(
        content,
        extraction.originalRawValue,
        lineHint,
      );

      if (foundIndex == -1) {
        return ReplacementResult.failure(
          'Multiple occurrences of string found, but none near expected line ${extraction.line}',
        );
      }

      return _replaceAtIndex(content, extraction, foundIndex);
    } else {
      // Single occurrence - safe to replace
      return _replaceAtIndex(content, extraction, stringIndex);
    }
  }

  int _findStringNearLine(String content, String searchString, int targetLine) {
    final lines = content.split('\n');

    // Search within ±5 lines of the target
    final searchRadius = 5;
    final startLine = (targetLine - searchRadius - 1).clamp(
      0,
      lines.length - 1,
    );
    final endLine = (targetLine + searchRadius - 1).clamp(0, lines.length - 1);

    int currentOffset = 0;

    // Calculate offset to start line
    for (int i = 0; i < startLine; i++) {
      currentOffset += lines[i].length + 1; // +1 for newline
    }

    // Search in the target range
    for (int i = startLine; i <= endLine; i++) {
      final line = lines[i];
      final indexInLine = line.indexOf(searchString);

      if (indexInLine != -1) {
        return currentOffset + indexInLine;
      }

      currentOffset += line.length + 1; // +1 for newline
    }

    return -1; // Not found in range
  }

  ReplacementResult _replaceAtIndex(
    String content,
    ExtractionData extraction,
    int index,
  ) {
    final replacement = _buildReplacement(extraction);
    final endIndex = index + extraction.originalRawValue.length;

    final before = content.substring(0, index);
    final after = content.substring(endIndex);
    final newContent = before + replacement + after;

    return ReplacementResult.success(newContent, replacement);
  }

  String _buildReplacement(ExtractionData extraction) {
    final functionName = _generateFunctionName(extraction.langqKey);

    if (extraction.placeholders.isEmpty) {
      // Simple string: LangQKey.buttonSave()
      return 'LangQKey.$functionName()';
    } else {
      // String with placeholders: LangQKey.welcomeMessage(userName: user.name)
      final params = extraction.placeholderMappings.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(', ');

      return 'LangQKey.$functionName($params)';
    }
  }

  String _generateFunctionName(String langqKey) {
    // Convert snake_case to camelCase
    final parts = langqKey.split('_');
    if (parts.isEmpty) return 'text';

    final camelCase =
        parts.first +
        parts
            .skip(1)
            .map(
              (part) =>
                  part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1),
            )
            .join('');

    return camelCase;
  }

  String _extractOriginalString(String content, ExtractionData extraction) {
    if (extraction.startOffset >= content.length ||
        extraction.endOffset > content.length ||
        extraction.startOffset < 0) {
      return '';
    }

    return content.substring(extraction.startOffset, extraction.endOffset);
  }

  String _replaceAtOffset(
    String content,
    ExtractionData extraction,
    String replacement,
  ) {
    final before = content.substring(0, extraction.startOffset);
    final after = content.substring(extraction.endOffset);

    return before + replacement + after;
  }

  Future<String> _addImportIfNeeded(String content) async {
    // Check if import already exists
    if (content.contains("import 'package:") &&
        content.contains("langq_key.g.dart")) {
      return content;
    }

    // Get package name
    final packageName = await PackageInfo.getPackageName();

    // Find the right place to add import (after other imports)
    final lines = content.split('\n');
    int importInsertIndex = 0;

    // Find last import line
    for (int i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.startsWith("import ")) {
        importInsertIndex = i + 1;
      } else if (trimmed.isNotEmpty && !trimmed.startsWith("//")) {
        break;
      }
    }

    // Insert the import
    final importLine =
        "import 'package:$packageName/l10n/generated/langq_key.g.dart';";
    lines.insert(importInsertIndex, importLine);

    return lines.join('\n');
  }
}

// Data model for extraction information
class ExtractionData {
  final String langqKey;
  final String value;
  final String originalRawValue;
  final String filePath;
  final int line;
  final int column;
  final int startOffset;
  final int endOffset;
  final List<String> placeholders;
  final Map<String, String> placeholderMappings;
  final String parentContext;

  ExtractionData({
    required this.langqKey,
    required this.value,
    required this.originalRawValue,
    required this.filePath,
    required this.line,
    required this.column,
    required this.startOffset,
    required this.endOffset,
    required this.placeholders,
    required this.placeholderMappings,
    required this.parentContext,
  });

  factory ExtractionData.fromJson(String key, Map<String, dynamic> json) {
    return ExtractionData(
      langqKey: key,
      value: json['value'],
      originalRawValue: json['original_raw_value'],
      filePath: json['file_path'],
      line: json['line_column']['line'],
      column: json['line_column']['column'],
      startOffset: json['offset']['start_offset'],
      endOffset: json['offset']['end_offset'],
      placeholders: List<String>.from(json['placeholders'] ?? []),
      placeholderMappings: Map<String, String>.from(
        json['placeholder_mappings'] ?? {},
      ),
      parentContext: json['parent_context'],
    );
  }
}

// Enhanced ReplacementResult
class ReplacementResult {
  final ReplacementStatus status;
  final String newContent;
  final String replacement;
  final String error;

  ReplacementResult.success(this.newContent, this.replacement)
    : status = ReplacementStatus.success,
      error = '';

  ReplacementResult.failure(this.error)
    : status = ReplacementStatus.failed,
      newContent = '',
      replacement = '';

  ReplacementResult.alreadyReplaced(this.replacement)
    : status = ReplacementStatus.alreadyReplaced,
      newContent = '',
      error = '';

  ReplacementResult.ambiguous(this.error)
    : status = ReplacementStatus.ambiguous,
      newContent = '',
      replacement = '';

  bool get success => status == ReplacementStatus.success;
  bool get isAlreadyReplaced => status == ReplacementStatus.alreadyReplaced;
  bool get isAmbiguous => status == ReplacementStatus.ambiguous;
  bool get failed => status == ReplacementStatus.failed;
}

enum ReplacementStatus { success, failed, alreadyReplaced, ambiguous }

class ReplacementStats {
  int success = 0;
  int alreadyReplaced = 0;
  int ambiguous = 0;
  int failed = 0;

  String getSummary() {
    final parts = <String>[];
    if (success > 0) parts.add('✨$success replaced');
    if (alreadyReplaced > 0) parts.add('✅$alreadyReplaced already done');
    if (ambiguous > 0) parts.add('🔄$ambiguous ambiguous');
    if (failed > 0) parts.add('❌$failed failed');

    return parts.isEmpty ? 'no changes' : parts.join(', ');
  }
}

String _truncateString(String str, [int maxLength = 30]) {
  if (str.length <= maxLength) return str;
  return '${str.substring(0, maxLength)}...';
}
