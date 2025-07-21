import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:langq_localization/src/model.dart';
import 'package:langq_localization/src/parser.dart';

class LangQController {
  static bool _isInitialized = false;
  static var l10TranslationsDirectory = 'lib/l10n/translations';
  static List<LangQData> langQData = [];
  static ValueNotifier<Locale> localeNotifier = ValueNotifier(
    Locale('en', 'US'),
  );

  static Future<void> init() async {
    if (!_isInitialized) {
      var localeName = Platform.localeName.split('_');
      localeNotifier = ValueNotifier(Locale(localeName[0], localeName[1]));
      _isInitialized = true;
      await _load();
    }
  }

  static Future<void> _load() async {
    langQData.clear();
    String jsonString;

    try {
      jsonString = await rootBundle.loadString(
        '$l10TranslationsDirectory/${localeNotifier.value.languageCode}-${localeNotifier.value.countryCode}.json',
      );
    } catch (e) {
      jsonString = await rootBundle.loadString(
        '$l10TranslationsDirectory/en-US.json',
      );
    }

    Map<String, dynamic> jsonMap = json.decode(jsonString);
    var localizedStrings = jsonMap.map((key, value) => MapEntry(key, value));

    Map<String, String> translations = {};
    Map<String, dynamic> definitions = {};

    for (var data in localizedStrings.entries) {
      if (data.key.contains(RegExp('@'))) {
        definitions.addEntries({data});
      } else {
        if (data.value is String) {
          translations.addEntries({MapEntry(data.key, data.value.toString())});
        }
      }
    }

    translations.forEach((k, v) {
      langQData.add(LangQData.from(key: k, text: v));
    });
  }

  static Future<void> setLocale(Locale locale) async {
    localeNotifier.value = locale;
    await _load();
  }

  static String resolve(String key, [Map<String, String>? args]) {
    var arguments = args;
    var langQValue = langQData.firstWhereOrNull((e) => e.key == key);

    return Parser.parse(langQValue?.text ?? '', args: arguments);
  }
}
