import 'dart:io';
import 'package:path/path.dart' as path;

import 'file_extraction_result.dart';

// lib/src/extraction/models.dart
class ExtractedString {
  final String value;
  final String originalRawValue;
  final List<String> placeholders;
  final Map<String, String> placeholderMappings;
  final Map<String, String> placeholderTypes;
  final String filePath;
  final int line;
  final int column;
  final String parentContext;
  final int startOffset;
  final int endOffset;
  String? suggestedKey;
  String? id;
  final String widgetHierarchy;
  final String parentClass;
  final String parentMethod;
  final String semanticContext;
  String? userContext;

  ExtractedString({
    required this.value,
    required this.originalRawValue,
    required this.placeholders,
    required this.placeholderMappings,
    required this.placeholderTypes,
    required this.filePath,
    required this.line,
    required this.column,
    required this.parentContext,
    required this.startOffset,
    required this.endOffset,
    this.suggestedKey,
    this.id,
    required this.widgetHierarchy,
    required this.parentClass,
    required this.parentMethod,
    required this.semanticContext,
    this.userContext,
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
      'value': originalRawValue, // Raw value as requested
      'icu_format': icuFormat,
      'placeholders': placeholders,
      'placeholder_mappings': placeholderMappings,
      'placeholder_types': placeholderTypes, // NEW
      'file_path': _getProjectRelativePath(), // NEW
      'file_name': filePath.split('/').last,
      'line': line,
      'column': column,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'code_snippet': _getCodeSnippet(),
      'widget_hierarchy': widgetHierarchy,
      'semantic_context': semanticContext, // Only if useful
      'ui_purpose': _inferUIPurpose(),
      'user_facing_type': _getUserFacingType(),
    };
  }

  String _getCodeSnippet() {
    return 'Line $line: $parentContext("$value")';
  }

  @override
  String toString() => 'ExtractedString("$value", $parentContext, line $line)';

  String _getProjectRelativePath() {
    final currentDir = Directory.current.path;

    // If the file path starts with current directory, make it relative
    if (filePath.startsWith(currentDir)) {
      final relativePath = path.relative(filePath, from: currentDir);
      return relativePath;
    }

    // If not, try to find project root markers
    final segments = filePath.split('/');

    // Look for common project structure indicators
    for (int i = segments.length - 1; i >= 0; i--) {
      final segment = segments[i];

      // Check if this segment indicates project root level
      if (segment == 'lib' ||
          segment == 'test' ||
          segment == 'web' ||
          segment == 'android' ||
          segment == 'ios') {
        // Go back one more level to include project name
        final projectRootIndex = i > 0 ? i - 1 : i;
        return segments.sublist(projectRootIndex).join('/');
      }
    }

    // Fallback: return the filename if we can't determine project structure
    return path.basename(filePath);
  }

  String _inferUIPurpose() {
    final hierarchy = widgetHierarchy.toLowerCase();
    final parent = parentContext.toLowerCase();

    if (hierarchy.contains('appbar') || parent.contains('title')) {
      return 'navigation_title';
    }
    if (parent.contains('button') || hierarchy.contains('button')) {
      return 'action_button';
    }
    if (parent.contains('dialog') || hierarchy.contains('dialog')) {
      return 'modal_content';
    }
    if (parent.contains('textfield') || parent.contains('hint')) {
      return 'form_input';
    }
    if (parent.contains('tooltip')) {
      return 'help_text';
    }
    if (parent.contains('snackbar') || hierarchy.contains('snackbar')) {
      return 'notification';
    }
    if (hierarchy.contains('drawer') || hierarchy.contains('navigation')) {
      return 'navigation_item';
    }

    return 'display_text';
  }

  String _getUserFacingType() {
    if (hasPlaceholders) {
      return 'dynamic_message';
    }

    final purpose = _inferUIPurpose();
    switch (purpose) {
      case 'action_button':
        return 'call_to_action';
      case 'navigation_title':
      case 'navigation_item':
        return 'navigation_label';
      case 'form_input':
        return 'user_input_guidance';
      case 'help_text':
        return 'assistance_text';
      case 'notification':
        return 'system_feedback';
      case 'modal_content':
        return 'dialog_message';
      default:
        return 'informational_text';
    }
  }
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
