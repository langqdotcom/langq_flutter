// lib/src/extraction/extraction_config.dart
import 'dart:io';
import 'package:yaml/yaml.dart';

class ExtractionConfig {
  final List<String> exclude;
  final List<String> ignoreWords;
  final List<String> ignoreMarkers;
  final int minLength;

  ExtractionConfig({
    required this.exclude,
    required this.ignoreWords,
    required this.ignoreMarkers,
    required this.minLength,
  });

  static Future<ExtractionConfig> load() async {
    final file = File('langq.yaml');
    if (!await file.exists()) {
      await _createDefaultConfig();
      return _default();
    }

    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content) as Map?;

      if (yaml == null) return _default();

      // NEW: Handle nested extraction structure
      final extraction = yaml['extraction'] as Map? ?? {};

      return ExtractionConfig(
        exclude: _parseList(extraction['exclude']) ?? _getDefaultExcludes(),
        ignoreWords: _parseList(yaml['ignore_words']) ?? ['TODO', 'FIXME'],
        ignoreMarkers: _parseList(yaml['ignore_markers']) ?? ['@langq-ignore'],
        minLength: yaml['min_length'] as int? ?? 0,
      );
    } catch (e) {
      print('Warning: Error reading langq.yaml: $e');
      return _default();
    }
  }

  static List<String> _getDefaultExcludes() {
    return [
      'lib/l10n/generated/**', // Always excluded
    ];
  }

  static List<String>? _parseList(dynamic value) {
    if (value == null) return null;
    if (value is List) return value.cast<String>();
    return [value.toString()];
  }

  static ExtractionConfig _default() {
    return ExtractionConfig(
      exclude: _getDefaultExcludes(),
      ignoreWords: [],
      ignoreMarkers: ['@langq-ignore'],
      minLength: 0,
    );
  }

  // Add this to ExtractionConfig class:
  void printDebug() {
    print('📋 Config loaded:');
    print('  exclude: $exclude');
    print('  ignoreWords: $ignoreWords');
    print('  ignoreMarkers: $ignoreMarkers');
    print('  minLength: $minLength');
  }

  static Future<void> _createDefaultConfig() async {
    final defaultYaml = '''# This file is auto-generated. Modify as needed.
extraction:
  exclude:
    # These are always excluded (not configurable)
    - "lib/l10n/generated/**"
    
    # Recommended exclusions (remove lines to include)
    - "**/*.g.dart"
    - "**/*.freezed.dart"

''';

    final file = File('langq.yaml');
    await file.writeAsString(defaultYaml);
    print('Created default langq.yaml configuration file');
  }
}
