import 'models.dart';

// lib/src/extraction/file_extraction_result.dart
class FileExtractionResult {
  final String filePath;
  final List<ExtractedString> strings = [];
  final List<ExtractionError> errors = [];
  final DateTime extractionTime;

  FileExtractionResult(this.filePath) : extractionTime = DateTime.now();

  void addString(ExtractedString string) {
    strings.add(string);
  }

  void addStrings(List<ExtractedString> newStrings) {
    strings.addAll(newStrings);
  }

  void addError(ExtractionError error) {
    errors.add(error);
  }

  bool get hasErrors => errors.isNotEmpty;
  bool get hasStrings => strings.isNotEmpty;

  int get totalStrings => strings.length;

  // Group strings by parent context (widget/function name)
  Map<String, List<ExtractedString>> get stringsByContext {
    final Map<String, List<ExtractedString>> result = {};

    for (final string in strings) {
      result.putIfAbsent(string.parentContext, () => []).add(string);
    }

    return result;
  }

  // Group strings by whether they have placeholders or not
  Map<bool, List<ExtractedString>> get stringsByPlaceholderStatus {
    final Map<bool, List<ExtractedString>> result = {};

    for (final string in strings) {
      result.putIfAbsent(string.hasPlaceholders, () => []).add(string);
    }

    return result;
  }

  // Get strings that have placeholders
  List<ExtractedString> get stringsWithPlaceholders {
    return strings.where((s) => s.hasPlaceholders).toList();
  }

  // Get strings without placeholders
  List<ExtractedString> get simpleStrings {
    return strings.where((s) => !s.hasPlaceholders).toList();
  }

  // Get unique parent contexts
  Set<String> get uniqueContexts {
    return strings.map((s) => s.parentContext).toSet();
  }

  // Get statistics
  Map<String, int> get contextStats {
    final stats = <String, int>{};
    for (final string in strings) {
      stats[string.parentContext] = (stats[string.parentContext] ?? 0) + 1;
    }
    return stats;
  }

  @override
  String toString() {
    return 'FileExtractionResult(path: $filePath, strings: ${strings.length}, errors: ${errors.length})';
  }
}

class ExtractionError {
  final String message;
  final int? lineNumber;
  final int? columnNumber;
  final String? context;
  final DateTime timestamp;

  ExtractionError({
    required this.message,
    this.lineNumber,
    this.columnNumber,
    this.context,
  }) : timestamp = DateTime.now();

  @override
  String toString() {
    final location = lineNumber != null ? ' at line $lineNumber' : '';
    return 'ExtractionError: $message$location';
  }
}
