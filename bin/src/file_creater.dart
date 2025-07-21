import 'dart:convert';
import 'dart:io';

class FileCreater {
  static var l10Directory = 'lib/l10n';
  static var l10TranslationsDirectory = 'lib/l10n/translations';
  static var l10GeneratedDirectory = 'lib/l10n/generated';

  static Future<void> createDirectory() async {
    if (!(await Directory(l10Directory).exists())) {
      await Directory(l10Directory).create();
    }
  }

  static Future<void> createTranslationsDirectory() async {
    await createDirectory();
    if (!(await Directory(l10TranslationsDirectory).exists())) {
      await Directory(l10TranslationsDirectory).create();
    }
  }

  static Future<void> createGeneratedDirectory() async {
    await createDirectory();
    if (!(await Directory(l10GeneratedDirectory).exists())) {
      await Directory(l10GeneratedDirectory).create();
    }
  }

  static Future<void> writeLocalisationFileFromData(
    String fileName,
    Map data,
  ) async {
    await createTranslationsDirectory();
    var filePath = '$l10TranslationsDirectory/$fileName';
    final file = File(filePath);

    // Create a pretty-printed JSON string
    var encoder = const JsonEncoder.withIndent('  ');
    String prettyJson = encoder.convert(data);

    await file.writeAsString(prettyJson, encoding: utf8);
  }

  static Future<void> writeKeysFile(List<String> keys) async {
    await createGeneratedDirectory();
    var filePath = '$l10GeneratedDirectory/langq_key.g.dart';

    var content = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// *************************************************
// Auto-generated Dart file
// *************************************************

class LangQKey {
${keys.join("\n")}
}

''';

    final file = File(filePath);
    await file.writeAsString(content);
    await format(filePath);
  }

  static Future<void> writeKeyAsFunctionFile(List<String> keys) async {
    await createGeneratedDirectory();
    var filePath = '$l10GeneratedDirectory/langq_key.g.dart';

    var content = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// *************************************************
// Auto-generated Dart file
// *************************************************

import 'package:langq_localization/langq.dart';

class LangQKey {
${keys.join("\n")}
}

''';

    final file = File(filePath);
    await file.writeAsString(content);
    await format(filePath);
  }

  static Future<void> writeSupportedLocales({
    required List<String> locales,
    required List<String> langCodes,
  }) async {
    await createGeneratedDirectory();
    var filePath = '$l10GeneratedDirectory/langq_locales.g.dart';

    var content = '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// *************************************************
// Auto-generated Dart file
// *************************************************

import 'dart:ui';

class LangQLocales {
static List<Locale> supportedLocales = [${"\n"}${langCodes.join(",\n")}];

${locales.join("\n")}
}

''';

    // Write the file
    final file = File(filePath);
    await file.writeAsString(content);
    await format(filePath);
  }

  static Future<void> format(String filePath) async {
    await Process.run('dart', ['format', filePath], runInShell: true);
  }
}
