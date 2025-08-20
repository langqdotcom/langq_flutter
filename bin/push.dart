// lib/src/commands/push_command.dart
import 'dart:io';
import 'dart:convert';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'extraction/json_exporter.dart';
import 'src/api_key_service.dart';

void main(List<String> args) async {
  await PushCommand().run();
}

class PushCommand extends Command<void> {
  @override
  String get name => 'push';

  @override
  String get description => 'Push extracted strings to Lang Q for translation';

  PushCommand() {
    // argParser
    //   ..addFlag(
    //     'force',
    //     abbr: 'f',
    //     help: 'Force push even if no changes detected',
    //     defaultsTo: false,
    //   )
    //   ..addFlag(
    //     'dry-run',
    //     abbr: 'd',
    //     help: 'Show what would be pushed without actually pushing',
    //     defaultsTo: false,
    //   );
  }

  @override
  Future<void> run() async {
    print('📤 Preparing to push strings to Lang Q...');

    final projectPath = Directory.current.path;
    final extractedPath = JsonExporter.getExtractedPath(projectPath);

    // Check if extracted file exists
    final extractedFile = File(extractedPath);
    if (!await extractedFile.exists()) {
      print('❌ No extracted strings found.');
      print('💡 Run `dart run langq_localization:extract` first');
      exit(1);
    }

    try {
      // Load extracted strings
      final extractedData = await _loadExtractedStrings(extractedFile);
      final strings = extractedData['strings'] as List;

      if (strings.isEmpty) {
        print('ℹ️  No strings to push');
        return;
      }

      print('📊 Found ${strings.length} strings to push');

      // Load config for API key
      final apiKey = ApiKeyService.getApiKey();

      // if (argResults?['dry-run'] == true) {
      //   await _showDryRunInfo(strings, apiKey);
      //   return;
      // }

      // Check for existing mappings to avoid duplicates
      final existingMappings = await _loadExistingMappings(projectPath);
      final newStrings = _filterNewStrings(strings, existingMappings);

      // if (newStrings.isEmpty && !(argResults?['force'] == true)) {
      //   print('✅ All strings already pushed. Use --force to push again.');
      //   return;
      // }

      print('🚀 Pushing ${newStrings.length} new strings...');

      // Push to API
      final response = await _pushToApi(newStrings, apiKey);

      if (response['success'] == true) {
        // Save mapping of pushed strings
        await _savePushMapping(projectPath, {}, extractedData);

        print('✅ Successfully pushed ${newStrings.length} strings');
        print('🔑 ${response['keys_generated']} keys generated');
        print('🌐 Translation started for ${response['languages']} languages');
        print('💡 Run `dart run langq_localization:pull` to get translations');
      } else {
        throw Exception(response['error'] ?? 'Unknown error');
      }
    } catch (e) {
      print('❌ Error pushing strings: $e');
      exit(1);
    }
  }

  Future<Map<String, dynamic>> _loadExtractedStrings(File file) async {
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _loadExistingMappings(String projectPath) async {
    final mappingFile = File(JsonExporter.getPushMappingPath(projectPath));

    if (!await mappingFile.exists()) {
      return {};
    }

    try {
      final content = await mappingFile.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      print('⚠️  Could not load existing mappings: $e');
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

  // Future<void> _showDryRunInfo(List<dynamic> strings, String apiKey) async {
  //   print('\n📋 Dry run - would push to api.langq.com/push:');
  //   print('🔑 API Key: ${apiKey.substring(0, 8)}...');
  //   print('📊 Payload:');

  //   final sampleStrings =
  //       strings.take(3).map((s) {
  //         final string = s as Map<String, dynamic>;
  //         return {
  //           'id': string['id'],
  //           'value': string['value'],
  //           'icu_format': string['icu_format'],
  //           'placeholders': string['placeholders'],
  //         };
  //       }).toList();

  //   print(
  //     const JsonEncoder.withIndent(
  //       '  ',
  //     ).convert({'strings': sampleStrings, 'total_count': strings.length}),
  //   );

  //   print('\n💡 Run without --dry-run to actually push');
  // }

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

    print('🌐 Sending ${strings.length} strings to Lang Q...');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'User-Agent': 'langq_localization_dart/1.0.0',
      },
      body: jsonEncode(payload),
    );

    print(
      'response ${response.statusCode == 200} ${jsonDecode(response.body)}',
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody =
          response.body.isNotEmpty ? response.body : 'No response body';
      throw Exception('API Error ${response.statusCode}: $errorBody');
    }
  }

  Future<void> _savePushMapping(
    String projectPath,
    Map<String, dynamic> mappings,
    Map<String, dynamic> extractedData,
  ) async {
    final mappingFile = File(JsonExporter.getPushMappingPath(projectPath));

    // Load existing mappings
    final existingMappings = await _loadExistingMappings(projectPath);

    // Merge with new mappings
    existingMappings.addAll(mappings);

    final pushData = {
      'last_push': DateTime.now().toIso8601String(),
      'extraction_id': extractedData['metadata']['extraction_id'],
      'mappings': existingMappings, // string_id -> langq_key
      'push_history': [
        ...(existingMappings['push_history'] as List? ?? []),
        {
          'pushed_at': DateTime.now().toIso8601String(),
          'strings_count': mappings.length,
          'extraction_id': extractedData['metadata']['extraction_id'],
        },
      ],
    };

    await mappingFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(pushData),
    );

    print(
      '💾 Push mapping saved to: ${JsonExporter.getPushMappingPath(projectPath)}',
    );
  }
}
