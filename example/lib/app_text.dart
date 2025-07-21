import 'package:flutter/material.dart';

class Apptext extends StatelessWidget {
  const Apptext(this.text, {this.align = TextAlign.center, super.key});

  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
      ),
    );
  }
}
