import 'dart:io';
import 'extraction_config.dart';
import 'models.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;
import '../src/utils.dart';

// lib/src/extraction/string_extractor.dart

class StringExtractor {
  final ExtractionConfig config;
  final Set<String> _seenStrings = {}; // Prevent duplicates

  StringExtractor(this.config);

  Future<List<ExtractedString>> extractFromProject(String projectPath) async {
    _seenStrings.clear();
    final results = <ExtractedString>[];

    final libDir = Directory(path.join(projectPath, 'lib'));
    if (!await libDir.exists()) {
      throw Exception('lib directory not found');
    }

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final relativePath = path.relative(entity.path, from: projectPath);

        if (_shouldIgnoreFile(relativePath)) {
          print('🚫 Ignoring: $relativePath');
          continue;
        }

        try {
          final strings = await _extractFromFile(entity);
          results.addAll(strings);
          print('📄 ${path.basename(entity.path)}: ${strings.length} strings');

          // Debug output
          for (final string in strings) {
            print('   - "${string.value}" (${string.parentContext})');
          }
        } catch (e) {
          print('⚠️  Error in ${entity.path}: $e');
        }
      }
    }

    print('✅ Total: ${results.length} unique strings');
    return results;
  }

  bool _shouldIgnoreFile(String relativePath) {
    for (final pattern in config.exclude) {
      if (_matchesPattern(relativePath, pattern)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesPattern(String filePath, String pattern) {
    // Simple pattern matching like your old code
    if (pattern.contains('**')) {
      final regexPattern = pattern
          .replaceAll('**/', '.*/')
          .replaceAll('*', '[^/]*')
          .replaceAll('.', r'\.');
      return RegExp('^$regexPattern\$').hasMatch(filePath);
    }
    if (pattern.contains('*')) {
      final regexPattern = pattern.replaceAll('*', '.*');
      return RegExp(regexPattern).hasMatch(filePath);
    }
    return filePath.contains(pattern);
  }

  Future<List<ExtractedString>> _extractFromFile(File file) async {
    final content = await file.readAsString();
    final result = parseString(content: content, throwIfDiagnostics: false);

    final visitor = _StringExtractionVisitor(
      filePath: file.path,
      source: content,
      config: config,
      seenStrings: _seenStrings,
    );

    result.unit.accept(visitor);
    return visitor.extractedStrings;
  }
}

class _StringExtractionVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final String source;
  final ExtractionConfig config;
  final Set<String> seenStrings;
  final List<ExtractedString> extractedStrings = [];

  _StringExtractionVisitor({
    required this.filePath,
    required this.source,
    required this.config,
    required this.seenStrings,
  });

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    final value = node.stringValue;
    if (value == null) {
      super.visitSimpleStringLiteral(node);
      return;
    }

    // Skip if already seen (prevent duplicates)
    if (seenStrings.contains(value)) {
      super.visitSimpleStringLiteral(node);
      return;
    }

    // Skip imports/exports
    if (_isInDirective(node)) {
      super.visitSimpleStringLiteral(node);
      return;
    }

    // Apply filters
    if (!_shouldExtractString(value)) {
      super.visitSimpleStringLiteral(node);
      return;
    }

    // Simple strings have no placeholders
    final placeholders = <String>[];
    final placeholderMappings = <String, String>{}; // Empty for simple strings

    // Get location
    final location = _getSourceLocation(node);

    // Get parent context
    final parentContext = _getParentContext(node);

    final extracted = ExtractedString(
      value: value,
      originalRawValue: node.toSource(),
      placeholders: placeholders,
      placeholderMappings: placeholderMappings, // Empty map
      filePath: filePath,
      line: location.lineNumber,
      column: location.columnNumber,
      parentContext: parentContext,
      startOffset: node.offset,
      endOffset: node.end,
    );

    seenStrings.add(value); // Mark as seen
    extractedStrings.add(extracted);
    super.visitSimpleStringLiteral(node);
  }

  ({int lineNumber, int columnNumber}) _getSourceLocation(StringLiteral node) {
    final lines = source.substring(0, node.offset).split('\n');
    return (lineNumber: lines.length, columnNumber: lines.last.length + 1);
  }

  Map<String, String> _createPlaceholderMappings(StringInterpolation node) {
    final mappings = <String, String>{};

    for (final element in node.elements) {
      if (element is InterpolationExpression) {
        final originalExpr = element.expression.toSource();
        final placeholderName = _createMeaningfulPlaceholderName(originalExpr);
        mappings[placeholderName] = originalExpr;
      }
    }

    return mappings;
  }
  // In _StringExtractionVisitor class, add this method:

  @override
  void visitStringInterpolation(StringInterpolation node) {
    final value = _extractStringValue(node);

    // Skip if already seen (prevent duplicates)
    if (seenStrings.contains(value)) {
      super.visitStringInterpolation(node);
      return;
    }

    // Skip imports/exports
    if (_isInDirective(node)) {
      super.visitStringInterpolation(node);
      return;
    }

    // Apply filters
    if (!_shouldExtractString(value)) {
      super.visitStringInterpolation(node);
      return;
    }

    // Extract placeholders from interpolation
    final placeholders = _extractPlaceholdersFromInterpolation(node);
    final placeholderMappings = _createPlaceholderMappings(node);

    // Get location
    final location = _getSourceLocation(node);

    // Get parent context
    final parentContext = _getParentContext(node);

    final extracted = ExtractedString(
      value: value,
      originalRawValue: node.toSource(),
      placeholders: placeholders,
      placeholderMappings:
          placeholderMappings, // Has mappings for interpolation
      filePath: filePath,
      line: location.lineNumber,
      column: location.columnNumber,
      parentContext: parentContext,
      startOffset: node.offset,
      endOffset: node.end,
    );

    seenStrings.add(value); // Mark as seen
    extractedStrings.add(extracted);
    super.visitStringInterpolation(node);
  }

  // Helper methods for interpolation
  String _extractStringValue(StringInterpolation node) {
    final buffer = StringBuffer();
    for (final element in node.elements) {
      if (element is InterpolationString) {
        buffer.write(element.value);
      } else if (element is InterpolationExpression) {
        final expr = element.expression;
        final exprString = expr.toSource();
        // Use the meaningful placeholder name
        final placeholderName = _createMeaningfulPlaceholderName(exprString);
        buffer.write('\${$placeholderName}');
      }
    }
    return buffer.toString();
  }

  List<String> _extractPlaceholdersFromInterpolation(StringInterpolation node) {
    final placeholders = <String>[];

    for (final element in node.elements) {
      if (element is InterpolationExpression) {
        final exprString = element.expression.toSource();
        final name = _createMeaningfulPlaceholderName(exprString);
        if (!placeholders.contains(name)) {
          placeholders.add(name);
        }
      }
    }

    return placeholders;
  }

  bool _isInDirective(StringLiteral node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is ImportDirective ||
          current is ExportDirective ||
          current is PartDirective) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  bool _shouldExtractString(String value) {
    // Length check
    if (value.length < config.minLength) return false;

    // Ignore words check
    for (final word in config.ignoreWords) {
      if (value.contains(word)) return false;
    }

    // Basic filters (from your old code)
    if (RegExp(r'^\d+$').hasMatch(value)) return false; // Pure numbers
    if (value.startsWith('package:') || value.startsWith('dart:')) return false;
    if (RegExp(r'^https?://').hasMatch(value)) return false;
    if (RegExp(r'^[A-Z_][A-Z0-9_]*$').hasMatch(value))
      return false; // Constants
    if (value.startsWith('assets/')) return false;

    return true;
  }

  // Fixed placeholder name creation using your helper function
  String _createMeaningfulPlaceholderName(String expression) {
    // Handle different expression types

    // Simple variable: appleCount -> appleCount
    if (RegExp(r'^\w+$').hasMatch(expression)) {
      return expression;
    }

    // Property access: Orange.count -> orangeCount
    if (expression.contains('.')) {
      final parts = expression.split('.');
      if (parts.length == 2) {
        final object = parts[0];
        final property = parts[1];

        // Use your helper function
        return toCamelCase('${object}_$property');
      } else {
        // Multiple dots: User.profile.name -> userProfileName
        return toCamelCase(parts.join('_'));
      }
    }

    // Method calls: items.length() -> itemsLength
    if (expression.contains('(')) {
      final cleanExpr = expression.replaceAll(RegExp(r'\(\)'), '');
      return _createMeaningfulPlaceholderName(cleanExpr);
    }

    // Array access: items[0] -> itemsFirst or items0
    if (expression.contains('[')) {
      final cleanExpr = expression.replaceAll(RegExp(r'\[[^\]]*\]'), '_item');
      return _createMeaningfulPlaceholderName(cleanExpr);
    }

    // Complex expressions: use your helper function
    return toCamelCase(expression);
  }

  String _getParentContext(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      if (current is InstanceCreationExpression) {
        return current.constructorName.type.name2.lexeme;
      }
      if (current is MethodInvocation) {
        return current.methodName.name;
      }
      if (current is NamedExpression) {
        return current.name.label.name;
      }
      current = current.parent;
    }

    return 'unknown';
  }
}
