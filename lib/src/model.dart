import 'package:flutter/widgets.dart';

class LangQData {
  LangQData({required this.key, required this.text});
  final String key;
  final String text;

  factory LangQData.from({required String key, required String text}) {
    return LangQData(key: key, text: text);
  }
}

class LangQValue {
  LangQValue({
    required this.currentLocale,
    required this.localizationsDelegates,
  });

  final Locale currentLocale;
  final Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates;
}

class IcuBlock {
  IcuBlock({
    required this.statement,
    required this.argName,
    required this.type,
    required this.value,
  });

  String statement;
  String argName;
  String type;
  String value;
}
