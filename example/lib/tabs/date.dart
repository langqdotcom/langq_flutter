import 'package:example/app_text.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';

class DateFormat extends StatelessWidget {
  const DateFormat({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Apptext(DateTime.now().dateFormat()));
  }
}
