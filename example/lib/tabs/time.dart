import 'package:example/app_text.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';

class TimeFormat extends StatelessWidget {
  const TimeFormat({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Apptext(DateTime.now().timeFormat()));
  }
}
