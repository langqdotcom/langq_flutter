import 'file_extraction_result.dart';

// lib/src/extraction/models.dart
class ExtractedString {
  final String value;
  final String originalRawValue;
  final List<String> placeholders;
  final Map<String, String> placeholderMappings;
  final String filePath;
  final int line;
  final int column;
  final String parentContext;
  final int startOffset;
  final int endOffset;
  String? suggestedKey;
  String? id; // New: unique identifier for tracking

  ExtractedString({
    required this.value,
    required this.originalRawValue,
    required this.placeholders,
    required this.placeholderMappings,
    required this.filePath,
    required this.line,
    required this.column,
    required this.parentContext,
    required this.startOffset,
    required this.endOffset,
    this.suggestedKey,
    this.id,
  });

  bool get hasPlaceholders => placeholders.isNotEmpty;

  String get icuFormat {
    String result = value;
    result = result.replaceAllMapped(
      RegExp(r'\$\{([^}]+)\}'),
      (m) => '{${m.group(1)}}',
    );
    result = result.replaceAllMapped(
      RegExp(r'\$(\w+)'),
      (m) => '{${m.group(1)}}',
    );
    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'original_raw_value': originalRawValue,
      'icu_format': icuFormat,
      'placeholders': placeholders,
      'placeholder_mappings': placeholderMappings,
      'file_path': filePath,
      'file_name': filePath.split('/').last,
      'line': line,
      'column': column,
      'parent_context': parentContext,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'suggested_key': suggestedKey,
      'has_placeholders': hasPlaceholders,
      'code_snippet': _getCodeSnippet(),
    };
  }

  String _getCodeSnippet() {
    return 'Line $line: $parentContext("$value")';
  }

  @override
  String toString() => 'ExtractedString("$value", $parentContext, line $line)';
}

enum Priority {
  high, // Definitely user-facing
  medium, // Likely user-facing
  low, // Possibly user-facing
}

// lib/src/extraction/extraction_result.dart
class ExtractionResult {
  final Map<String, FileExtractionResult> fileResults = {};

  void addFileResult(FileExtractionResult result) {
    fileResults[result.filePath] = result;
  }

  List<ExtractedString> getAllStrings() {
    return fileResults.values.expand((result) => result.strings).toList();
  }

  int get totalStringCount => getAllStrings().length;

  // Group all strings by parent context
  Map<String, List<ExtractedString>> getContextDistribution() {
    final distribution = <String, List<ExtractedString>>{};

    for (final string in getAllStrings()) {
      distribution.putIfAbsent(string.parentContext, () => []).add(string);
    }

    return distribution;
  }

  // Get count by context
  Map<String, int> getContextCounts() {
    final counts = <String, int>{};

    for (final string in getAllStrings()) {
      counts[string.parentContext] = (counts[string.parentContext] ?? 0) + 1;
    }

    return counts;
  }

  // Get placeholder statistics
  Map<String, dynamic> getPlaceholderStats() {
    final allStrings = getAllStrings();
    final withPlaceholders = allStrings.where((s) => s.hasPlaceholders).length;
    final withoutPlaceholders = allStrings.length - withPlaceholders;

    return {
      'total': allStrings.length,
      'with_placeholders': withPlaceholders,
      'without_placeholders': withoutPlaceholders,
      'placeholder_percentage':
          allStrings.isEmpty
              ? 0
              : (withPlaceholders / allStrings.length * 100).round(),
    };
  }

  // Get all unique placeholders used across the project
  Set<String> getAllPlaceholderNames() {
    final placeholders = <String>{};

    for (final string in getAllStrings()) {
      placeholders.addAll(string.placeholders);
    }

    return placeholders;
  }

  // Get files with extraction errors
  List<FileExtractionResult> getFilesWithErrors() {
    return fileResults.values.where((result) => result.hasErrors).toList();
  }
}
