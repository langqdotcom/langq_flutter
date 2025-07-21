import 'package:example/app_text.dart';
import 'package:example/l10n/generated/langq_key.g.dart';
import 'package:flutter/material.dart';

class PlaceholderText extends StatelessWidget {
  const PlaceholderText({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Apptext(LangQKey.welcomeMessage(userName: 'John')));
  }
}
