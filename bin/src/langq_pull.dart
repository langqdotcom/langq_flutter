import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'file_creater.dart';
import 'utils.dart';
import 'model.dart';
import 'string_replacer.dart';

class LangQPull {
  LangQPull({required this.apiKey, required this.canGenerateAsFucntion}) {
    init();
  }

  final String apiKey;
  final bool canGenerateAsFucntion;
  init() async {
    final loading = _startLoading();
    final List<String> langCodes = [];
    final List<String> locales = [];

    try {
      var response = await http.post(
        Uri.parse("https://ymsreanckxyrthosfqiq.supabase.co/functions/v1/pull"),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      if (response.statusCode == 200) {
        var bytes = utf8.decode(response.bodyBytes);
        var data = jsonDecode(bytes);

        String baseLocale = data['base_language'] ?? 'en';
        List languages = data['languages'] ?? [];

        // print('extract data: ${data['extract_data']}');

        languages.sort();

        for (String language in languages) {
          var localeName = language;
          localeName = localeName.replaceAll('_', '-');
          var localeSplitted = localeName.split('-');

          String? langCode = localeSplitted.firstOrNull;
          localeSplitted.removeAt(0);

          String? countryCode = localeSplitted.firstOrNull;
          if (langCode != null) {
            if (countryCode == null) {
              // supportedLocale.add("Locale('$langCode')");
              langCodes.add(langCode);
              locales.add("static const $langCode = Locale('$langCode');");
            } else {
              // supportedLocale.add("Locale('$langCode','$countryCode')");
              langCodes.add("$langCode$countryCode");
              locales.add(
                "static const $langCode$countryCode = Locale('$langCode','$countryCode');",
              );
            }
          }
          Map? translation = data['translations'][localeName];

          if (translation != null) {
            if (localeName == baseLocale) {
              if (canGenerateAsFucntion) {
                await generateKeyAsFunction(translation);
                await _replaceExtractedStrings(data);
              } else {
                await generateKey(translation);
              }
            }

            await FileCreater.writeLocalisationFileFromData(
              '$localeName.json',
              translation,
            );
          }
        }

        await FileCreater.writeSupportedLocales(
          locales: locales,
          langCodes: langCodes,
        );

        await loading.cancel();
        stdout.write('\r');
        stdout.write('\r\x1B[2K');
        if (languages.isNotEmpty) {
          stdout.write(
            '${CommandLineColor.green}✓ Downloaded ${languages.length} translations!\n',
          );
          stdout.write('\r${CommandLineColor.white}');
        }
        exit(0);
      } else {
        var data = jsonDecode(response.body);
        await loading.cancel();
        stdout.write('\r');
        stdout.write('\r\x1B[2K');
        stdout.write('${CommandLineColor.red}❌ Error: ${data['error']}\n');
        stdout.write('\r${CommandLineColor.white}');
        exit(0);
      }
    } catch (e) {
      loading.cancel();
      stdout.write('\r');
      stdout.write('\r\x1B[2K');
      stdout.write('${CommandLineColor.red}❌ Error: $e\n');
      stdout.write('\r${CommandLineColor.white}');
      exit(0);
    }
  }

  /// Function to display a loading
  StreamSubscription<void> _startLoading() {
    final List<String> spinner = ['-', '\\', '|', '/'];
    int index = 0;

    return Stream.periodic(Duration(milliseconds: 150), (_) {
      stdout.write(
        '\r⏳ Downloading l10n files ${spinner[index % spinner.length]}',
      );
      index++;
    }).listen((_) {});
  }

  Future<void> generateKey(Map file) async {
    List<String> langQKeys = [];

    for (var data in file.entries) {
      var key = data.key;
      var keyCamelCase = toCamelCase(key);
      langQKeys.add(
        """  /// Base: ${data.value} \n   static String get $keyCamelCase{\n return '$key';\n}\n""",
      );
    }

    langQKeys.sort();
    await FileCreater.writeKeysFile(langQKeys);
  }

  Future<void> generateKeyAsFunction(Map file) async {
    List<String> langQKeys = [];
    // bool hasPlural = false;

    for (var data in file.entries) {
      var key = data.key;
      var keyCamelCase = toCamelCase(key);

      var placeholders = getPlaceholders(data.value);
      placeholders.sort((a, b) => a.name.compareTo(b.name));

      // hasPlural = placeholders.any((e) => e.type == 'plural');

      if (placeholders.isNotEmpty) {
        var params = placeholders
            .map((e) {
              if (e.type == 'plural') {
                return 'required num ${e.name}';
              }
              return 'required String ${e.name}';
            })
            .toList()
            .join(', ');

        var args = placeholders
            .map((e) {
              if (e.type == 'plural') {
                return "'${e.name}': '\$${e.name}'";
              }
              return "'${e.name}':${e.name}";
            })
            .toList()
            .join(', ');

        var function =
            """  /// Base: ${data.value} \n   static String $keyCamelCase({$params}){\n return LangQ.text('$key',args:{$args});\n}\n""";
        langQKeys.add(function);
      } else {
        langQKeys.add(
          """  /// Base: ${data.value} \n   static String $keyCamelCase(){\n return LangQ.text('$key');\n}\n""",
        );
      }
    }

    langQKeys.sort();

    await FileCreater.writeKeyAsFunctionFile(langQKeys);
  }

  static List<IcuPlaceholder> getPlaceholders(String message) {
    var escapedMessage = escapeIcu(message);
    return _extractPlaceholders(escapedMessage);
  }

  static String escapeIcu(String message) {
    // Escape '' first
    var replaced = message.replaceAll("''", "__‹ESC_QUOTE›__");

    // Escape '{...}' if enclosed in single quotes
    replaced = replaced.replaceAllMapped(
      RegExp(r"'(\{[^}]+\})'"),
      (match) => match
          .group(1)!
          .replaceAll('{', '__‹ESC_OPEN›__')
          .replaceAll('}', '__‹ESC_CLOSE›__'),
    );

    return replaced;
  }

  static List<IcuPlaceholder> _extractPlaceholders(String message) {
    final placeholders = <String, String>{};

    void extract(String str) {
      final icuBlockReg = RegExp(r'\{(\w+),\s*(plural|select),');
      final placeholderReg = RegExp(r'\{(\w+)\}');

      for (final match in icuBlockReg.allMatches(str)) {
        final name = match.group(1)!;
        final type = match.group(2)!;
        placeholders[name] = type;
      }

      for (final match in placeholderReg.allMatches(str)) {
        final name = match.group(1)!;
        if (!placeholders.containsKey(name)) {
          placeholders[name] = 'none';
        }
      }
    }

    extract(message);

    return placeholders.entries
        .map((entry) => IcuPlaceholder(entry.key, entry.value))
        .toList();
  }

  // In pull_command.dart, after generating functions:

  Future<void> _replaceExtractedStrings(
    Map<String, dynamic> apiResponse,
  ) async {
    final extractionData = apiResponse['extract_data'] as List?;

    if (extractionData == null || extractionData.isEmpty) {
      print('ℹ️  No extraction data for replacement');
      return;
    }

    print('🔄 Replacing extracted strings with function calls...');

    // Convert API data to ExtractionData objects
    final extractions = <String, ExtractionData>{};
    for (final entry in extractionData) {
      final key = toCamelCase(entry['key_name']);
      final data = entry['extract'] as Map<String, dynamic>;
      extractions[key] = ExtractionData.fromJson(key, data);
    }

    print('replacement data prepared ${extractions}');

    // Perform replacements
    final replacer = CodeReplacer(extractions);
    await replacer.replaceAllStrings();
  }
}
