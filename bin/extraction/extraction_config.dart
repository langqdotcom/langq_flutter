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
      return _default();
    }

    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content) as Map?;

      if (yaml == null) return _default();

      return ExtractionConfig(
        exclude: _parseList(yaml['exclude']) ?? [],
        ignoreWords: _parseList(yaml['ignore_words']) ?? ['TODO', 'FIXME'],
        ignoreMarkers: _parseList(yaml['ignore_markers']) ?? ['@no-translate'],
        minLength: yaml['min_length'] as int? ?? 2,
      );
    } catch (e) {
      print('⚠️  Error reading langq.yaml: $e');
      return _default();
    }
  }

  static List<String> _parseList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<String>();
    return [value.toString()];
  }

  static ExtractionConfig _default() {
    return ExtractionConfig(
      exclude: ['lib/generated/**', '**/*.g.dart'],
      ignoreWords: ['TODO', 'FIXME'],
      ignoreMarkers: ['@no-translate'],
      minLength: 2,
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
}
