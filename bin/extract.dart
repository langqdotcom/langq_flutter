// lib/src/commands/extract_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'extraction/extraction_config.dart';
import 'extraction/string_extractor.dart';
import 'extraction/json_exporter.dart';

void main(List<String> args) async {
  await ExtractCommand().run();
}

class ExtractCommand extends Command<void> {
  @override
  String get name => 'extract';

  @override
  String get description =>
      'Extract hardcoded strings and save to JSON for review';

  ExtractCommand() {
    argParser
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output JSON file path',
        defaultsTo: 'langq_extracted_strings.json',
      )
      ..addFlag(
        'open',
        help: 'Open the JSON file after creation',
        defaultsTo: false,
      );
  }

  @override
  Future<void> run() async {
    print('🔍 Extracting strings from project...');

    final config = await ExtractionConfig.load();
    final extractor = StringExtractor(config);

    try {
      final strings = await extractor.extractFromProject(
        Directory.current.path,
      );

      if (strings.isEmpty) {
        print('✅ No strings found to extract');
        return;
      }

      print('\n📊 Extraction Summary:');
      print('Total strings: ${strings.length}');

      // Group by context for preview
      final byContext = <String, int>{};
      for (final string in strings) {
        byContext[string.parentContext] =
            (byContext[string.parentContext] ?? 0) + 1;
      }

      print('\nBy widget/context:');
      for (final entry in byContext.entries) {
        print('  ${entry.key}: ${entry.value}');
      }

      // Show strings with placeholders
      final withPlaceholders = strings.where((s) => s.hasPlaceholders).length;
      print('\nPlaceholder info:');
      print('  With placeholders: $withPlaceholders');
      print('  Without placeholders: ${strings.length - withPlaceholders}');

      // Export to JSON
      final outputPath = argResults?['output'] as String?;
      final jsonPath = await JsonExporter.exportToJson(
        strings,
        projectPath: outputPath,
      );

      print('\n✅ Extraction complete!');
      print('📁 Review the strings in: $jsonPath');
      print('📝 Next steps:');
      print('   1. Review and edit the JSON file if needed');
      print(
        '   2. Run `dart run langq_localization:push` to send for translation',
      );

      // Optionally open the file
      if (argResults?['open'] == true) {
        await _openFile(jsonPath);
      }
    } catch (e) {
      print('❌ Error: $e');
      exit(1);
    }
  }

  Future<void> _openFile(String path) async {
    try {
      if (Platform.isWindows) {
        await Process.run('start', [path], runInShell: true);
      } else if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (e) {
      print('Could not open file automatically: $e');
    }
  }
}
