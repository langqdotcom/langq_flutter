// lib/src/cli_commands/extract_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'src/string_extractor.dart';
import 'src/langq_translate.dart';
import 'package:dotenv/dotenv.dart';

void main(List<String> args) async {
  await ExtractCommand().run();
}

class ExtractCommand extends Command {
  @override
  final name = 'translate';

  @override
  final description = 'Extract untranslated strings from your Flutter app';

  // ExtractCommand();

  @override
  Future<void> run() async {
    final projectPath = Directory.current.path;
    final extractor = FlutterStringExtractor();
    stdout.write('Extracting Strings');

    print('🔍 Scanning Flutter project for untranslated strings...');

    try {
      final extractedStrings = await extractor.extractFromProject(projectPath);

      if (extractedStrings.isEmpty) {
        print(
          '✅ No untranslated strings found! Your app is already fully localized.',
        );
        return;
      }

      stdout.write('📊 Found ${extractedStrings.length} untranslated strings');

      var dotenv = DotEnv();
      dotenv.load();

      String? apiKey = dotenv['LANGQ_API_KEY'];

      print('apikey is $apiKey');

      LangQTranslate(apiKey: apiKey!, extractedStrings: extractedStrings);
    } catch (e) {
      print('❌ Error extracting strings: $e');
      exit(1);
    }
  }
}
