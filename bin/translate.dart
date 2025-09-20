// lib/src/commands/translate_command.dart
import 'dart:io';
import 'package:args/command_runner.dart';
import 'src/extraction/extraction_config.dart';
import 'src/extraction/string_extractor.dart';
import 'src/extraction/json_exporter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'src/langq_pull.dart';
import 'src/api_key_service.dart';

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
    // argParser
    //   ..addFlag(
    //     'skip-extract',
    //     help: 'Skip extraction and use existing extracted_strings.json',
    //     defaultsTo: false,
    //   )
    //   ..addFlag(
    //     'extract-only',
    //     help: 'Only extract strings, don\'t push or replace',
    //     defaultsTo: false,
    //   )
    //   ..addFlag(
    //     'no-replace',
    //     help: 'Push and pull but don\'t replace code',
    //     defaultsTo: false,
    //   );
  }

  @override
  Future<void> run() async {
    print('🚀 Starting full translation workflow...');

    final projectPath = Directory.current.path;
    final config = await ExtractionConfig.load();

    try {
      // Step 1: Extract (unless skipped)
      List<dynamic> strings;
      // if (argResults?['skip-extract'] == true) {
      //   print('\n📂 Step 1: Loading existing extracted strings...');
      //   strings = await _loadExistingStrings(projectPath);
      // } else {
      print('\n🔍 Step 1: Extracting strings...');
      strings = await _extractStrings(projectPath, config);
      // }

      if (strings.isEmpty) {
        print('✅ No strings found to translate');
        return;
      }

      // Early exit for extract-only
      // if (argResults?['extract-only'] == true) {
      //   print(
      //     '✅ Extraction complete. Use --no-extract-only to continue with push/pull',
      //   );
      //   return;
      // }

      // Step 2: Push
      print('\n📤 Step 2: Pushing strings to Lang Q...');
      await _pushStrings(strings, config);

      // Step 3: Pull
      print('\n📥 Step 3: Pulling translations and generating functions...');
      LangQPull(apiKey: ApiKeyService.getApiKey(), canGenerateAsFucntion: true);
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

  // Step 2: Push strings
  Future<Map<String, dynamic>> _pushStrings(
    List<dynamic> strings,
    ExtractionConfig config,
  ) async {
    final apiKey = ApiKeyService.getApiKey();

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
}
