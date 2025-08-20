// lib/src/commands/translate_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:dotenv/dotenv.dart';
import 'extraction/extraction_config.dart';
import 'extraction/string_extractor.dart';
import 'extraction/json_exporter.dart';
import 'src/package_info.dart';
import 'src/string_replacer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'src/langq_pull.dart';

void main(List<String> args) async {
  await TranslateCommand().run();
}

class TranslateCommand extends Command<void> {
  @override
  String get name => 'translate';

  @override
  String get description =>
      'Extract, push, pull and replace strings in one command';

  TranslateCommand() {
    argParser
      ..addFlag(
        'skip-extract',
        help: 'Skip extraction and use existing extracted_strings.json',
        defaultsTo: false,
      )
      ..addFlag(
        'extract-only',
        help: 'Only extract strings, don\'t push or replace',
        defaultsTo: false,
      )
      ..addFlag(
        'no-replace',
        help: 'Push and pull but don\'t replace code',
        defaultsTo: false,
      );
  }

  @override
  Future<void> run() async {
    print('🚀 Starting full translation workflow...');

    final projectPath = Directory.current.path;
    final config = await ExtractionConfig.load();

    try {
      // Step 1: Extract (unless skipped)
      List<dynamic> strings;
      if (argResults?['skip-extract'] == true) {
        print('\n📂 Step 1: Loading existing extracted strings...');
        strings = await _loadExistingStrings(projectPath);
      } else {
        print('\n🔍 Step 1: Extracting strings...');
        strings = await _extractStrings(projectPath, config);
      }

      if (strings.isEmpty) {
        print('✅ No strings found to translate');
        return;
      }

      // Early exit for extract-only
      if (argResults?['extract-only'] == true) {
        print(
          '✅ Extraction complete. Use --no-extract-only to continue with push/pull',
        );
        return;
      }

      // Step 2: Push
      print('\n📤 Step 2: Pushing strings to Lang Q...');
      final pushResponse = await _pushStrings(strings, config);

      // Step 3: Pull
      print('\n📥 Step 3: Pulling translations and generating functions...');
      LangQPull(apiKey: _getApiKey(config), canGenerateAsFucntion: true);
      // final pullResponse = await _pullTranslations(config);

      print('\n🎉 Translation workflow complete!');
    } catch (e) {
      print('\n❌ Translation workflow failed: $e');
      exit(1);
    }
  }

  // Step 1: Extract strings
  Future<List<dynamic>> _extractStrings(
    String projectPath,
    ExtractionConfig config,
  ) async {
    final extractor = StringExtractor(config);
    final extractedStrings = await extractor.extractFromProject(projectPath);

    if (extractedStrings.isEmpty) {
      return [];
    }

    // Save to JSON
    await JsonExporter.exportToJson(extractedStrings, projectPath: projectPath);
    print('✅ Extracted ${extractedStrings.length} strings');

    return extractedStrings.map((s) => s.toJson()).toList();
  }

  // Load existing extracted strings
  Future<List<dynamic>> _loadExistingStrings(String projectPath) async {
    final extractedPath = JsonExporter.getExtractedPath(projectPath);
    final file = File(extractedPath);

    if (!await file.exists()) {
      throw Exception(
        'No extracted strings found. Run without --skip-extract first.',
      );
    }

    final content = await file.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    final strings = data['strings'] as List<dynamic>;

    print('✅ Loaded ${strings.length} existing strings');
    return strings;
  }

  // Step 2: Push strings
  Future<Map<String, dynamic>> _pushStrings(
    List<dynamic> strings,
    ExtractionConfig config,
  ) async {
    final apiKey = _getApiKey(config);

    // Load existing mappings to avoid duplicates
    final projectPath = Directory.current.path;
    final existingMappings = await _loadExistingMappings(projectPath);
    final newStrings = _filterNewStrings(strings, existingMappings);

    if (newStrings.isEmpty) {
      print('✅ All strings already pushed');
      return {'success': true, 'keys_generated': 0, 'languages': []};
    }

    print('📤 Pushing ${newStrings.length} new strings...');

    final response = await _pushToApi(newStrings, apiKey);

    print('>>>>>> $response');

    if (response['success'] == true) {
      await _savePushMapping(projectPath, {}, {'strings': strings});
      print('✅ Successfully pushed ${newStrings.length} strings');
      print('🔑 ${response['keys_generated']} keys generated');
    } else {
      throw Exception(response['error'] ?? 'Push failed');
    }

    return response;
  }

  // Step 3: Pull translations
  Future<Map<String, dynamic>> _pullTranslations(
    ExtractionConfig config,
  ) async {
    final apiKey = _getApiKey(config);

    print('📥 Downloading translations...');

    final uri = Uri.parse('https://api.langq.com/pull');
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'User-Agent': 'langq_localization_dart/1.0.0',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Pull failed: ${response.statusCode} ${response.body}');
    }

    final pullResponse = jsonDecode(response.body) as Map<String, dynamic>;

    // Generate translation files and functions (existing pull logic)
    await _generateTranslationFiles(pullResponse);
    await _generateFunctionFiles(pullResponse);

    print('✅ Generated translation files and functions');
    return pullResponse;
  }

  // Step 4: Replace strings
  Future<void> _replaceStrings(
    Map<String, dynamic> pullResponse,
    String projectPath,
  ) async {
    final extractionData =
        pullResponse['extraction_data'] as Map<String, dynamic>?;

    if (extractionData == null || extractionData.isEmpty) {
      print('ℹ️  No extraction data for replacement');
      return;
    }

    // Get package name
    final packageName = await PackageInfo.getPackageName();

    // Convert API data to ExtractionData objects
    final extractions = <String, ExtractionData>{};
    for (final entry in extractionData.entries) {
      final key = entry.key;
      final data = entry.value as Map<String, dynamic>;
      extractions[key] = ExtractionData.fromJson(key, data);
    }

    // Perform replacements
    final replacer = CodeReplacer(extractions);
    await replacer.replaceAllStrings();

    print('✅ String replacement complete');
  }

  // Helper methods (reuse from other commands)
  String _getApiKey(ExtractionConfig config) {
    // Try environment variable
    String? apiKey = Platform.environment['LANGQ_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      return apiKey;
    }

    if (apiKey == null) {
      var dotenv = DotEnv();
      dotenv.load();

      apiKey = dotenv['LANGQ_API_KEY'];

      if (apiKey != null && apiKey.isNotEmpty) {
        return apiKey;
      }
    }

    throw Exception(
      'API key not found. Set it in langq.yaml or LANGQ_API_KEY environment variable',
    );
  }

  Future<Map<String, dynamic>> _loadExistingMappings(String projectPath) async {
    final mappingFile = File(JsonExporter.getPushMappingPath(projectPath));

    if (!await mappingFile.exists()) {
      return {};
    }

    try {
      final content = await mappingFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data['mappings'] as Map<String, dynamic>? ?? {};
    } catch (e) {
      return {};
    }
  }

  List<Map<String, dynamic>> _filterNewStrings(
    List<dynamic> strings,
    Map<String, dynamic> existingMappings,
  ) {
    final newStrings = <Map<String, dynamic>>[];

    for (final string in strings) {
      final stringMap = string as Map<String, dynamic>;
      final id = stringMap['id'] as String;

      if (!existingMappings.containsKey(id)) {
        newStrings.add(stringMap);
      }
    }

    return newStrings;
  }

  Future<Map<String, dynamic>> _pushToApi(
    List<Map<String, dynamic>> strings,
    String apiKey,
  ) async {
    final uri = Uri.parse(
      'https://ymsreanckxyrthosfqiq.supabase.co/functions/v1/auto-translate',
    );

    final payload = {
      'strings': strings,
      'metadata': {
        'pushed_at': DateTime.now().toIso8601String(),
        'client': 'langq_localization_dart',
        'version': '1.0.0',
      },
    };

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'User-Agent': 'langq_localization_dart/1.0.0',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('API Error ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> _savePushMapping(
    String projectPath,
    Map<String, dynamic> mappings,
    Map<String, dynamic> extractedData,
  ) async {
    final mappingFile = File(JsonExporter.getPushMappingPath(projectPath));

    final existingMappings = await _loadExistingMappings(projectPath);
    existingMappings.addAll(mappings);

    final pushData = {
      'last_push': DateTime.now().toIso8601String(),
      'mappings': existingMappings,
    };

    await mappingFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(pushData),
    );
  }

  // Placeholder methods for existing pull functionality
  Future<void> _generateTranslationFiles(Map<String, dynamic> response) async {
    // TODO: Implement existing pull logic for generating translation JSON files
    print('📝 Generated translation files');
  }

  Future<void> _generateFunctionFiles(Map<String, dynamic> response) async {
    // TODO: Implement existing pull logic for generating LangQKey functions
    print('🔧 Generated function files');
  }

  void _printSummary(
    int totalStrings,
    Map<String, dynamic> pushResponse,
    Map<String, dynamic> pullResponse,
  ) {
    print('\n📊 Summary:');
    print('  📄 Total strings processed: $totalStrings');
    print('  📤 Keys generated: ${pushResponse['keys_generated'] ?? 0}');
    print('  🌐 Languages: ${pushResponse['languages']?.join(', ') ?? 'none'}');
    print(
      '  🔧 Functions generated: ${pullResponse['functions_generated'] ?? 'N/A'}',
    );
    print(
      '  ✨ Code replacements: ${pullResponse['replacements_made'] ?? 'N/A'}',
    );

    print('\n🎯 Next steps:');
    print('  • Test your app to ensure all translations work');
    print('  • Review generated functions in lib/l10n/generated/');
    print('  • Commit the changes to version control');
  }
}
