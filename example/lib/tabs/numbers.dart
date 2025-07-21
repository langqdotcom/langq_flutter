import 'package:example/app_text.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';

class NumbersFormat extends StatelessWidget {
  const NumbersFormat({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(child: Apptext(123456789.12.numberFormat()));
  }
}
