import 'package:example/app_text.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';

class PercentageFormat extends StatelessWidget {
  const PercentageFormat({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Apptext(0.255.percentageFormat()));
  }
}
