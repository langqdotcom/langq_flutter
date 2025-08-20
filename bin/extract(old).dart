// lib/src/cli_commands/extract_command.dart
import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;
import 'src/string_extractor.dart';

void main(List<String> args) async {
  await ExtractCommand().run();
}

class ExtractCommand extends Command {
  @override
  final name = 'extract';

  @override
  final description = 'Extract untranslated strings from your Flutter app';

  // ExtractCommand();

  @override
  Future<void> run() async {
    final projectPath = Directory.current.path;
    final extractor = FlutterStringExtractor();

    print('🔍 Scanning Flutter project for untranslated strings...');

    try {
      final extractedStrings = await extractor.extractFromProject(projectPath);

      if (extractedStrings.isEmpty) {
        print(
          '✅ No untranslated strings found! Your app is already fully localized.',
        );
        return;
      }

      print('📊 Found ${extractedStrings.length} untranslated strings');

      // Always save to lib/l10n/generated/extract.json
      await _writeExtractionFile(extractedStrings, projectPath);
      await _generateSummaryFile(extractedStrings, projectPath);
    } catch (e) {
      print('❌ Error extracting strings: $e');
      exit(1);
    }
  }

  Future<void> _writeExtractionFile(
    List<ExtractedString> extractedStrings,
    String projectPath,
  ) async {
    // Save to lib/l10n/generated/extract.json
    final extractPath = path.join(
      projectPath,
      'lib',
      'l10n',
      'generated',
      'extract.json',
    );

    // Create the output directory if it doesn't exist
    final outputFile = File(extractPath);
    final outputDir = outputFile.parent;
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
      print('📁 Created directory: ${outputDir.path}');
    }

    // Create the extraction format optimized for replacement
    final extractionData = <String, Map<String, dynamic>>{};

    for (final string in extractedStrings) {
      extractionData[string.value] = {
        'fileName': string.filePath,
        'lineColumn': '${string.lineNumber}:${string.columnNumber}',
        'identifier': string.suggestedKey ?? 'unknown_key',
        'parameters': string.parameters,
        'context': string.context,
        'type': string.type.name,
      };
    }

    await outputFile.writeAsString(
      JsonEncoder.withIndent('  ').convert(extractionData),
    );
    print('📄 Extracted strings saved to $extractPath');
  }

  Future<void> _generateSummaryFile(
    List<ExtractedString> strings,
    String projectPath,
  ) async {
    final summaryPath = path.join(
      '$projectPath/lib/l10n/generated',
      'langq_extraction_summary.json',
    );
    final summary = {
      'version': '1.0',
      'extractedAt': DateTime.now().toIso8601String(),
      'sourceLanguage': 'en',
      'totalStrings': strings.length,
      'extractionFile': 'lib/l10n/generated/extract.json',
      'summary': _generateSummary(strings),
      'nextSteps': [
        '1. Review extracted strings in lib/l10n/generated/extract.json',
        '2. Run: dart run langq_localization:init',
        '3. Add your Lang Q API key to .env file',
        '4. Upload for translation: dart run langq_localization:push',
        '5. Generate translated code: dart run langq_localization:pull',
      ],
    };

    await File(
      summaryPath,
    ).writeAsString(JsonEncoder.withIndent('  ').convert(summary));
    print('📋 Generated summary: langq_extraction_summary.json');
  }

  Map<String, dynamic> _generateSummary(List<ExtractedString> strings) {
    final byType = <String, int>{};
    final byFile = <String, int>{};

    for (final string in strings) {
      byType[string.type.name] = (byType[string.type.name] ?? 0) + 1;
      final fileName = path.basename(string.filePath);
      byFile[fileName] = (byFile[fileName] ?? 0) + 1;
    }

    return {'byType': byType, 'byFile': byFile};
  }
}
