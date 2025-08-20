// lib/src/string_extractor.dart
import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as path;

class ExtractedString {
  final String value;
  final List<String> parameters;
  final String filePath;
  final int lineNumber;
  final int columnNumber;
  final String context;
  final StringType type;
  String? suggestedKey;

  ExtractedString({
    required this.value,
    required this.parameters,
    required this.filePath,
    required this.lineNumber,
    required this.columnNumber,
    required this.context,
    required this.type,
    this.suggestedKey,
  });

  Map<String, dynamic> toJson() => {
    'value': value,
    'parameters': parameters,
    'filePath': filePath,
    'lineNumber': lineNumber,
    'columnNumber': columnNumber,
    'context': context,
    'type': type.name,
    'suggestedKey': suggestedKey,
  };
}

enum StringType {
  text, // Simple text widget
  appBarTitle, // AppBar title
  buttonLabel, // Button text
  hintText, // Input hints
  errorMessage, // Validation messages
  dialogTitle, // Dialog titles
  snackBarMessage, // SnackBar content
  tooltip, // Tooltip text
  accessibility, // Semantics labels
  other, // Generic string literals
}

class FlutterStringExtractor {
  final List<ExtractedString> extractedStrings = [];

  final Set<String> ignoredPatterns = {
    // String content patterns (not file patterns)
    r'^\d+$', // Pure numbers
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$', // Emails
    r'^https?://', // URLs
    r'^[{}[\]().,;:!?-]+$', // Pure punctuation
    r'^\w+://.*', // URIs
    r'^#[0-9A-Fa-f]{6}$', // Hex colors
    r'^\d{4}-\d{2}-\d{2}', // Dates
    r'^[A-Z_][A-Z0-9_]*$', // Constants
  };

  final List<String> fileIgnorePatterns = [
    // // Default patterns for generated files WITHIN lib/ folder
    // '*.g.dart', // Generated files (freezed, json_annotation, etc.)
    // '*.gr.dart', // AutoRoute generated files
    // '*.freezed.dart', // Freezed generated files
    // '*.config.dart', // Config generated files
    // '*.chopper.dart', // Chopper generated files
    // '*.mocks.dart', // Mockito generated files
    // 'generated/**', // Generated directory within lib/
    // 'l10n/generated/**', // Localization generated files
  ];

  Future<List<ExtractedString>> extractFromProject(String projectPath) async {
    extractedStrings.clear();

    // Load custom ignore patterns from .langqignore
    await _loadIgnoreFile(projectPath);

    final libDir = Directory(path.join(projectPath, 'lib'));
    if (!await libDir.exists()) {
      throw Exception('lib directory not found in $projectPath');
    }

    // Only extract from lib/ folder
    await _extractFromDirectory(libDir);
    _generateSuggestedKeys();

    return List.from(extractedStrings);
  }

  Future<void> _loadIgnoreFile(String projectPath) async {
    final ignoreFile = File(path.join(projectPath, '.langqignore'));
    if (await ignoreFile.exists()) {
      final lines = await ignoreFile.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          fileIgnorePatterns.add(trimmed);
        }
      }
      print(
        '📋 Loaded ${lines.where((l) => l.trim().isNotEmpty && !l.startsWith('#')).length} ignore patterns from .langqignore',
      );
    }
  }

  Future<void> _extractFromDirectory(Directory dir) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        // Get path relative to lib/ directory
        final libPath = path.dirname(dir.path);
        final relativePath = path.relative(entity.path, from: libPath);

        // Check if file should be ignored (relative to lib/)
        if (_shouldIgnoreFile(relativePath)) {
          print('🚫 Ignoring file: $relativePath');
          continue;
        }
        await _extractFromFile(entity);
      }
    }
  }

  bool _shouldIgnoreFile(String relativePath) {
    // relativePath is already relative to lib/ folder
    // Remove 'lib/' prefix if it exists
    final cleanPath =
        relativePath.startsWith('lib/')
            ? relativePath.substring(4)
            : relativePath;

    for (final pattern in fileIgnorePatterns) {
      if (_matchesGitIgnorePattern(cleanPath, pattern)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesGitIgnorePattern(String filePath, String pattern) {
    // Convert gitignore-style patterns to regex
    String regexPattern = pattern;

    // Handle different gitignore patterns
    if (pattern.startsWith('**/')) {
      // **/generated/** matches generated/ anywhere in the path
      regexPattern = pattern.substring(3); // Remove **/
      regexPattern = regexPattern.replaceAll('**/', '.*?/');
      regexPattern = regexPattern.replaceAll('*', '[^/]*');
      regexPattern = '(^|.*/)$regexPattern';
    } else if (pattern.endsWith('/**')) {
      // generated/** matches everything under generated/
      regexPattern = pattern.substring(0, pattern.length - 3); // Remove /**
      regexPattern = regexPattern.replaceAll('*', '[^/]*');
      regexPattern = '^$regexPattern(/.*)?';
    } else if (pattern.contains('/')) {
      // Path-based pattern (relative to lib/)
      regexPattern = regexPattern.replaceAll('**/', '.*?/');
      regexPattern = regexPattern.replaceAll('*', '[^/]*');
      regexPattern = '^$regexPattern';
    } else {
      // Simple filename pattern
      regexPattern = regexPattern.replaceAll('*', '.*');
      regexPattern = '(^|.*/)$regexPattern';
    }

    try {
      return RegExp(regexPattern).hasMatch(filePath);
    } catch (e) {
      print('⚠️  Invalid ignore pattern: $pattern - $e');
      return false;
    }
  }

  // #################################

  Future<void> _extractFromFile(File file) async {
    try {
      print('Extracting file content ${file.path}');
      final content = await file.readAsString();
      final result = parseString(content: content, throwIfDiagnostics: false);

      // Check for parsing errors
      if (result.errors.isNotEmpty) {
        print('Parse errors in ${file.path}:');
        for (final error in result.errors) {
          print('  ${error.message}');
        }
      }

      final visitor = _StringExtractionVisitor(
        filePath: file.path,
        source: content,
        ignoredPatterns: ignoredPatterns,
      );

      result.unit.accept(visitor);

      // Better debugging
      print('Found ${visitor.extractedStrings.length} strings in ${file.path}');
      if (visitor.extractedStrings.isNotEmpty) {
      } else {
        print('No strings found - checking for string literals in AST...');
        // Debug: count all string literals
        final debugVisitor = _DebugStringVisitor();
        result.unit.accept(debugVisitor);
        print(
          'Total string literals found: ${debugVisitor.stringLiteralCount}',
        );
        print('Sample literals: ${debugVisitor.sampleLiterals}');
      }

      extractedStrings.addAll(visitor.extractedStrings);
    } catch (e, stackTrace) {
      print('Error parsing ${file.path}: $e');
      print('Stack trace: $stackTrace');
    }
  }

  //  >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>...

  void _generateSuggestedKeys() {
    try {
      final keyCounters = <String, int>{};

      for (int i = 0; i < extractedStrings.length; i++) {
        final string = extractedStrings[i];

        try {
          final baseKey = _generateBaseKey(string);
          // print('basekey for "${string.value}": $baseKey');

          final currentCount = keyCounters[baseKey] ?? 0;
          keyCounters[baseKey] = currentCount + 1;

          // Generate unique key
          if (currentCount == 0) {
            string.suggestedKey = baseKey;
          } else {
            string.suggestedKey = '${baseKey}_${currentCount + 1}';
          }

          // print('Generated key: ${string.suggestedKey}');
        } catch (e) {
          print('Error generating key for string "${string.value}": $e');
          // Fallback key generation
          string.suggestedKey = 'text_${i + 1}';
        }
      }

      print('Suggested keys generated for ${extractedStrings.length} strings');
    } catch (e) {
      print('Error in _generateSuggestedKeys: $e');
    }
  }

  String _generateBaseKey(ExtractedString string) {
    try {
      // Context-based key generation
      final context = string.context.toLowerCase();
      final prefix = _getKeyPrefix(string.type, context);

      // Clean and truncate the string value for key generation
      String cleanValue =
          string.value
              .replaceAll(RegExp(r'[^\w\s]'), '') // Remove non-word characters
              .replaceAll(
                RegExp(r'\s+'),
                '_',
              ) // Replace spaces with underscores
              .toLowerCase();

      // Handle empty clean value
      if (cleanValue.isEmpty) {
        cleanValue = 'text';
      }

      // Safely truncate to max 30 characters
      final maxLength = 30;
      if (cleanValue.length > maxLength) {
        cleanValue = cleanValue.substring(0, maxLength);
      }

      // Remove trailing underscores
      cleanValue = cleanValue.replaceAll(RegExp(r'_+$'), '');

      // Ensure we have a valid key
      if (cleanValue.isEmpty) {
        cleanValue = 'text';
      }

      return '${prefix}_$cleanValue';
    } catch (e) {
      print('Error generating base key for "${string.value}": $e');
      // Fallback to a simple key
      return '${_getKeyPrefix(string.type, '')}_text_${string.hashCode.abs()}';
    }
  }

  String _getKeyPrefix(StringType type, String context) {
    switch (type) {
      case StringType.appBarTitle:
        return 'appbar';
      case StringType.buttonLabel:
        return 'button';
      case StringType.hintText:
        return 'hint';
      case StringType.errorMessage:
        return 'error';
      case StringType.dialogTitle:
        return 'dialog';
      case StringType.snackBarMessage:
        return 'snackbar';
      case StringType.tooltip:
        return 'tooltip';
      case StringType.accessibility:
        return 'a11y';
      default:
        // Try to infer from context
        if (context.contains('login')) return 'login';
        if (context.contains('profile')) return 'profile';
        if (context.contains('settings')) return 'settings';
        return 'text';
    }
  }
}

// Debug visitor to see what string literals exist
class _DebugStringVisitor extends RecursiveAstVisitor<void> {
  int stringLiteralCount = 0;
  List<String> sampleLiterals = [];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    stringLiteralCount++;
    if (sampleLiterals.length < 5) {
      sampleLiterals.add(node.value);
    }
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    stringLiteralCount++;
    if (sampleLiterals.length < 5) {
      sampleLiterals.add(node.toSource());
    }
    super.visitStringInterpolation(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    stringLiteralCount++;
    if (sampleLiterals.length < 5) {
      sampleLiterals.add(node.toSource());
    }
    super.visitAdjacentStrings(node);
  }
}

class _StringExtractionVisitor extends RecursiveAstVisitor<void> {
  final String filePath;
  final String source;
  final Set<String> ignoredPatterns;
  final List<ExtractedString> extractedStrings = [];

  _StringExtractionVisitor({
    required this.filePath,
    required this.source,
    required this.ignoredPatterns,
  });

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _processStringLiteral(node);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    _processStringLiteral(node);
    super.visitStringInterpolation(node);
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    _processStringLiteral(node);
    super.visitAdjacentStrings(node);
  }

  void _processStringLiteral(StringLiteral node) {
    try {
      final stringValue = _extractStringValue(node);

      // Debug print every string we find
      // print('  Found string literal: "$stringValue"');

      if (_shouldIgnoreString(stringValue)) {
        // print('    -> Ignored (matches ignore pattern)');
        return;
      }

      final parameters = _extractParameters(node);
      final context = _extractContext(node);
      final type = _determineStringType(node, context);
      final location = _getSourceLocation(node);

      final extracted = ExtractedString(
        value: stringValue,
        parameters: parameters,
        filePath: filePath,
        lineNumber: location.lineNumber,
        columnNumber: location.columnNumber,
        context: context,
        type: type,
      );

      print('    -> Added: type=${type.name}, context="$context"');
      extractedStrings.add(extracted);
    } catch (e) {
      print('    -> Error extracting string: $e');
    }
  }

  // ... rest of the methods remain the same as in the previous version
  String _extractStringValue(StringLiteral node) {
    if (node is SimpleStringLiteral) {
      return node.value;
    } else if (node is StringInterpolation) {
      final buffer = StringBuffer();
      for (final element in node.elements) {
        if (element is InterpolationString) {
          buffer.write(element.value);
        } else if (element is InterpolationExpression) {
          final expr = element.expression;
          String placeholder = '{${_getPlaceholderName(expr)}}';
          buffer.write(placeholder);
        }
      }
      return buffer.toString();
    } else if (node is AdjacentStrings) {
      final buffer = StringBuffer();
      for (final string in node.strings) {
        buffer.write(_extractStringValue(string));
      }
      return buffer.toString();
    }

    print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');

    return node.toSource().replaceAll(RegExp(""), '');
  }

  List<String> _extractParameters(StringLiteral node) {
    final parameters = <String>[];

    if (node is StringInterpolation) {
      for (final element in node.elements) {
        if (element is InterpolationExpression) {
          parameters.add(_getPlaceholderName(element.expression));
        }
      }
    }

    return parameters;
  }

  String _getPlaceholderName(Expression expr) {
    if (expr is SimpleIdentifier) {
      return expr.name;
    } else if (expr is PropertyAccess) {
      return expr.propertyName.name;
    } else if (expr is MethodInvocation) {
      return expr.methodName.name;
    } else if (expr is PrefixedIdentifier) {
      return expr.identifier.name;
    }
    return 'value';
  }

  bool _shouldIgnoreString(String value) {
    if (value.trim().isEmpty) return true;
    if (value.trim().length <= 1) return true;

    for (final pattern in ignoredPatterns) {
      try {
        if (RegExp(pattern).hasMatch(value)) return true;
      } catch (e) {
        print('Invalid regex pattern: $pattern - $e');
      }
    }

    final lowerValue = value.toLowerCase().trim();
    final commonIgnored = {
      'materialapp',
      'scaffold',
      'appbar',
      'container',
      'widget',
      'row',
      'column',
      'center',
      'padding',
      'sizedbox',
      'text',
      'main',
      'build',
      'setstate',
      'initstate',
      'dispose',
      'context',
      'child',
      'children',
      'data',
      'value',
      'key',
      'name',
      'id',
      'flutter',
      'material',
      'cupertino',
      'package:',
      'import',
    };

    if (commonIgnored.contains(lowerValue)) return true;
    if (value.contains('/') &&
        (value.contains('.') || value.startsWith('assets'))) {
      return true;
    }
    if (value.startsWith('package:') || value.contains('dart:')) return true;
    if (RegExp(r'^[\d\s+\-*/().px%em]+$').hasMatch(value)) return true;

    return false;
  }

  String _extractContext(StringLiteral node) {
    final contextParts = <String>[];

    AstNode? current = node.parent;
    while (current != null && contextParts.length < 3) {
      if (current is NamedExpression) {
        contextParts.add('${current.name.label.name}:');
      } else if (current is InstanceCreationExpression) {
        final typeName = current.constructorName.type.name2.lexeme;
        contextParts.add(typeName);
      } else if (current is MethodDeclaration) {
        contextParts.add('${current.name.lexeme}()');
      } else if (current is ClassDeclaration) {
        contextParts.add(current.name.lexeme);
      } else if (current is VariableDeclaration) {
        contextParts.add('var ${current.name.lexeme}');
      }
      current = current.parent;
    }

    return contextParts.reversed.join(' > ');
  }

  StringType _determineStringType(StringLiteral node, String context) {
    final contextLower = context.toLowerCase();

    if (contextLower.contains('title:')) {
      if (contextLower.contains('appbar')) return StringType.appBarTitle;
      if (contextLower.contains('dialog')) return StringType.dialogTitle;
      return StringType.text;
    }

    if (contextLower.contains('hinttext:')) return StringType.hintText;
    if (contextLower.contains('errortext:')) return StringType.errorMessage;
    if (contextLower.contains('tooltip:')) return StringType.tooltip;
    if (contextLower.contains('semanticslabel:')) {
      return StringType.accessibility;
    }
    if (contextLower.contains('snackbar')) return StringType.snackBarMessage;
    if (contextLower.contains('button') ||
        contextLower.contains('elevatedbutton') ||
        contextLower.contains('textbutton') ||
        contextLower.contains('outlinedbutton')) {
      return StringType.buttonLabel;
    }

    return StringType.text;
  }

  ({int lineNumber, int columnNumber}) _getSourceLocation(StringLiteral node) {
    final lines = source.substring(0, node.offset).split('\n');
    return (lineNumber: lines.length, columnNumber: lines.last.length + 1);
  }
}
