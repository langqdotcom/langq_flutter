// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:langq_localization/src/langq_controller.dart';
import 'package:langq_localization/src/model.dart';

class LangQ extends StatelessWidget {
  const LangQ._builder({required this.builder, super.key});

  factory LangQ.builder({required _LangQWidgetBuilder builder, Key? key}) {
    return LangQ._builder(builder: builder, key: key);
  }

  final _LangQWidgetBuilder builder;

  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    await LangQController.init();
  }

  static Locale get currentLocale => LangQController.localeNotifier.value;

  static Iterable<LocalizationsDelegate<dynamic>> get _localizationsDelegates =>
      [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ];

  static void setLocale(Locale locale) {
    LangQController.setLocale(locale);
  }

  static String text(String langQKey, {Map<String, String>? args}) {
    return LangQController.resolve(langQKey, args);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LangQController.localeNotifier,
      builder: (context, value, child) {
        return builder(
          context,
          LangQValue(
            currentLocale: value,
            localizationsDelegates: _localizationsDelegates,
          ),
        );
      },
    );
  }
}

typedef _LangQWidgetBuilder =
    Widget Function(BuildContext context, LangQValue details);
