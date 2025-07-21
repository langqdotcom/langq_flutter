import 'package:example_2/app_text.dart';
import 'package:example_2/l10n/generated/langq_key.g.dart';
import 'package:example_2/main.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';

class Plural extends StatefulWidget {
  const Plural({super.key});

  @override
  State<Plural> createState() => _PluralState();
}

class _PluralState extends State<Plural> {
  int messageCount = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Apptext(
          LangQKey.messageNotification.tr(
            args: {'messageCount': messageCount.toString()},
          ),
        ),
      ),
      floatingActionButton: FloatingCounter(
        lable: 'Message',
        count: messageCount,
        onAdd: () {
          setState(() {
            messageCount++;
          });
        },
        onSub: () {
          if (messageCount > 0) {
            setState(() {
              messageCount--;
            });
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
