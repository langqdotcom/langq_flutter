import 'package:example/app_text.dart';
import 'package:example/l10n/generated/langq_key.g.dart';
import 'package:flutter/material.dart';

class SimpleText extends StatelessWidget {
  const SimpleText({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Apptext(LangQKey.helloWorld()));
  }
}
