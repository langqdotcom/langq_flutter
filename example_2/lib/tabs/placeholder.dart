import 'package:example_2/app_text.dart';
import 'package:example_2/l10n/generated/langq_key.g.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';

class PlaceholderText extends StatelessWidget {
  const PlaceholderText({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Apptext(LangQKey.welcomeMessage.tr(args: {'userName': 'John'})),
    );
  }
}
