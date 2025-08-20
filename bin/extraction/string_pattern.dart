import 'context_type.dart';
import 'models.dart';

// lib/src/extraction/string_pattern.dart
class StringPattern {
  final String pattern;
  final ContextType contextType;
  final Priority priority;
  final String? description;
  final bool multiline;
  final bool caseSensitive;

  const StringPattern({
    required this.pattern,
    required this.contextType,
    required this.priority,
    this.description,
    this.multiline = false,
    this.caseSensitive = true,
  });

  RegExp get regex =>
      RegExp(pattern, multiLine: multiline, caseSensitive: caseSensitive);

  /// Check if this pattern should capture the given context
  bool shouldCapture(String context) {
    // Additional context-specific logic can go here
    return true;
  }

  /// Get the capture group index for the string value
  int get stringCaptureGroup => 1; // Usually the first capture group

  /// Get additional metadata from the match
  Map<String, dynamic> getMetadata(RegExpMatch match) {
    return {
      'pattern_type': contextType.name,
      'priority': priority.name,
      'full_match': match.group(0),
    };
  }
}
