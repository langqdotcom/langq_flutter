import 'dart:io';
import 'extraction_config.dart';
import 'models.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;
import '../utils.dart';

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
          if (strings.isNotEmpty) {
            print('📄 ${path.basename(entity.path)}: ${strings.length} strings');
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

    // Check for ignore markers in the file
    final lines = content.split('\n');
    final ignoredLines = <int>{};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Check if this line contains @langq-ignore
      if (line.contains('@langq-ignore')) {
        // Ignore the next line (if it exists)
        if (i + 1 < lines.length) {
          ignoredLines.add(
            i + 2,
          ); // Line numbers are 1-based, next line is i+1, so i+2
        }
      }
    }

    final visitor = _StringExtractionVisitor(
      filePath: file.path,
      source: content,
      config: config,
      seenStrings: _seenStrings,
      ignoredLines: ignoredLines,
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
  final Set<int> ignoredLines;

  _StringExtractionVisitor({
    required this.filePath,
    required this.source,
    required this.config,
    required this.seenStrings,
    required this.ignoredLines,
  });

  // bool _shouldIgnoreString(String value) {
  //   // Empty or whitespace-only strings
  //   if (value.trim().isEmpty) return true;
  //   if (value.trim().length <= 1) return true;

  //   // Check against regex patterns
  //   for (final pattern in ignoredPatterns) {
  //     try {
  //       if (RegExp(pattern).hasMatch(value)) return true;
  //     } catch (e) {
  //       print('Invalid regex pattern: $pattern - $e');
  //     }
  //   }

  //   // NEW: Check if string is inside print/debugPrint calls
  //   if (_isInsidePrintCall()) return true;

  //   final lowerValue = value.toLowerCase().trim();

  //   // Common non-localizable strings (case-insensitive)
  //   final commonIgnored = {
  //     // Widget names and Flutter internals
  //     'materialapp', 'scaffold', 'appbar', 'container', 'widget',
  //     'row', 'column', 'center', 'padding', 'sizedbox', 'text',
  //     'elevated', 'button', 'icon', 'image', 'card', 'listview',
  //     'textfield', 'checkbox', 'radio', 'switch', 'slider',

  //     // Method names and common identifiers
  //     'main', 'build', 'setstate', 'initstate', 'dispose', 'context',
  //     'child', 'children', 'data', 'value', 'key', 'name', 'id',
  //     'index', 'item', 'items', 'list', 'map', 'set', 'string',

  //     // File paths and extensions
  //     'assets', 'images', 'lib', 'src', 'test', 'android', 'ios',
  //     'dart', 'json', 'yaml', 'xml', 'png', 'jpg', 'svg', 'gif',
  //     'pdf', 'mp4', 'mp3', 'wav',

  //     // Package names and imports
  //     'flutter', 'material', 'cupertino', 'package:', 'import',
  //     'export', 'part', 'library', 'show', 'hide', 'as',

  //     // Common development/debug strings
  //     'debug', 'test', 'mock', 'temp', 'tmp', 'example',
  //     'todo', 'fixme', 'hack', 'note', 'warning', 'error',

  //     // Network and API related
  //     'http', 'https', 'api', 'rest', 'json', 'xml', 'get',
  //     'post', 'put', 'delete', 'patch', 'head', 'options',

  //     // Database and storage
  //     'sql', 'database', 'table', 'column', 'row', 'index',
  //     'primary', 'foreign', 'unique', 'null', 'not', 'default',

  //     // Common abbreviations
  //     'ok', 'no', 'yes', 'on', 'off', 'true', 'false',
  //   };

  //   if (commonIgnored.contains(lowerValue)) return true;

  //   // Skip strings that are likely CSS/style values
  //   if (RegExp(r'^[\d\s+\-*/().px%em]+$').hasMatch(value)) return true;

  //   return false;
  // }

  bool _isInsidePrintCall(SimpleStringLiteral node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final methodName = current.methodName.name.toLowerCase();
        if (methodName == 'print' || methodName == 'debugprint') {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    final value = node.stringValue;
    final location = _getSourceLocation(node);

    if (value == null) {
      super.visitSimpleStringLiteral(node);
      return;
    }

    // Check if this line should be ignored
    if (ignoredLines.contains(location.lineNumber)) {
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

    if (_isInsidePrintCall(node)) {
      super.visitSimpleStringLiteral(node);
      return;
    }

    // Skip strings that look like file paths
    if (value.contains('/') &&
        (value.contains('.') || value.startsWith('assets'))) {
      super.visitSimpleStringLiteral(node);
      return;
    }

    // Simple strings have no placeholders
    final placeholders = <String>[];
    final placeholderMappings = <String, String>{}; // Empty for simple strings

    // Get location

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
      widgetHierarchy: _getWidgetHierarchy(node), // NEW
      parentClass: _getParentClass(node), // NEW
      parentMethod: _getParentMethod(node), // NEW
      semanticContext: _inferSemanticContext(node), // NEW
      placeholderTypes: _getPlaceholderTypesFromAST(
        node,
        placeholders,
        placeholderMappings,
      ),
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
    // Get location
    final location = _getSourceLocation(node);

    // Check if this line should be ignored
    if (ignoredLines.contains(location.lineNumber)) {
      super.visitStringInterpolation(node);
      return;
    }

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
      widgetHierarchy: _getWidgetHierarchy(node), // NEW
      parentClass: _getParentClass(node), // NEW
      parentMethod: _getParentMethod(node), // NEW
      semanticContext: _inferSemanticContext(node), // NEW
      placeholderTypes: _getPlaceholderTypesFromAST(
        node,
        placeholders,
        placeholderMappings,
      ),
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

    // Skip strings that don't contain any alphabetic characters outside of interpolated expressions
    // Remove all ${...} placeholders and check if remaining text has alphabets
    final textWithoutPlaceholders = value.replaceAll(RegExp(r'\$\{[^}]*\}'), '');
    if (!RegExp(r'[a-zA-Z]').hasMatch(textWithoutPlaceholders)) {
      return false;
    }

    // Ignore words check
    for (final word in config.ignoreWords) {
      if (value.contains(word)) return false;
    }

    // Basic filters (from your old code)
    if (RegExp(r'^\d+$').hasMatch(value)) return false; // Pure numbers
    if (value.startsWith('package:') || value.startsWith('dart:')) return false;
    if (RegExp(r'^https?://').hasMatch(value)) return false;
    if (RegExp(r'^[A-Z_][A-Z0-9_]*$').hasMatch(value)) {
      return false; // Constants
    }
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

  String _getWidgetHierarchy(AstNode node) {
    final hierarchy = <String>[];
    AstNode? current = node.parent;

    while (current != null && hierarchy.length < 4) {
      if (current is InstanceCreationExpression) {
        final typeName = current.constructorName.type.name2.lexeme;
        if (typeName.isNotEmpty) {
          hierarchy.add(typeName);
        }
      } else if (current is NamedExpression) {
        // Capture named parameters like title:, child:, etc.
        hierarchy.add('${current.name.label.name}:');
      }
      current = current.parent;
    }

    return hierarchy.reversed.join(' > ');
  }

  String _getParentClass(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      if (current is ClassDeclaration) {
        return current.name.lexeme;
      }
      current = current.parent;
    }

    return 'unknown';
  }

  String _getParentMethod(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      if (current is MethodDeclaration) {
        return current.name.lexeme;
      } else if (current is FunctionDeclaration) {
        return current.name.lexeme;
      }
      current = current.parent;
    }

    return 'unknown';
  }

  String _inferSemanticContext(AstNode node) {
    final hierarchy = _getWidgetHierarchy(node).toLowerCase();
    final parentContext = _getParentContext(node).toLowerCase();

    // Infer semantic meaning based on context
    if (hierarchy.contains('appbar') && parentContext.contains('title')) {
      return 'app_bar_title';
    }
    if (hierarchy.contains('appbar')) {
      return 'app_bar_content';
    }
    if (parentContext.contains('button') || hierarchy.contains('button')) {
      return 'button_text';
    }
    if (parentContext.contains('tooltip')) {
      return 'tooltip_text';
    }
    if (parentContext.contains('dialog')) {
      return 'dialog_content';
    }
    if (parentContext.contains('snackbar')) {
      return 'snackbar_message';
    }
    if (parentContext.contains('textfield') || parentContext.contains('hint')) {
      return 'input_text';
    }

    return 'general_text';
  }

  Map<String, String> _getPlaceholderTypesFromAST(
    AstNode node,
    List<String> placeholders,
    Map<String, String> mappings,
  ) {
    final types = <String, String>{};

    for (final placeholder in placeholders) {
      final originalExpr = mappings[placeholder] ?? placeholder;
      final baseVar = originalExpr.split('.').first;

      // Find the variable type in the current class
      String? varType = _findVariableTypeInCurrentClass(node, baseVar);

      if (varType != null) {
        types[placeholder] = varType;
      } else {
        // Fallback to pattern matching
        types[placeholder] = _inferTypeFromName(baseVar);
      }
    }

    return types;
  }

  String? _findVariableTypeInCurrentClass(AstNode node, String variableName) {
    AstNode? current = node;

    while (current != null) {
      if (current is ClassDeclaration) {
        for (final member in current.members) {
          if (member is FieldDeclaration) {
            for (final variable in member.fields.variables) {
              if (variable.name.lexeme == variableName) {
                return member.fields.type?.toString() ?? 'dynamic';
              }
            }
          }
        }
        break;
      }
      current = current.parent;
    }

    return null;
  }

  String _inferTypeFromName(String variableName) {
    final lower = variableName.toLowerCase();

    if (lower.contains('count') ||
        lower.contains('index') ||
        lower.contains('number')) {
      return 'int';
    }
    if (lower.contains('price') ||
        lower.contains('amount') ||
        lower.contains('rate')) {
      return 'double';
    }
    if (lower.startsWith('is') ||
        lower.startsWith('has') ||
        lower.contains('enabled')) {
      return 'bool';
    }

    return 'String';
  }
}
