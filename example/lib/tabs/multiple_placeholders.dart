import 'package:example/app_text.dart';
import 'package:example/l10n/generated/langq_key.g.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';

class MultiplePlaceholders extends StatefulWidget {
  const MultiplePlaceholders({super.key});

  @override
  State<MultiplePlaceholders> createState() => _MultiplePlaceholdersState();
}

class _MultiplePlaceholdersState extends State<MultiplePlaceholders> {
  int itemCount = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Apptext(
          LangQKey.messageOrder(
            itemCount: itemCount,
            date: DateTime.now().dateFormat(),
            amount: 1299.currencyFormat(),
          ),
        ),
      ),
      floatingActionButton: FloatingCounter(
        lable: 'Item',
        count: itemCount,
        onAdd: () {
          setState(() {
            itemCount++;
          });
        },
        onSub: () {
          if (itemCount > 0) {
            setState(() {
              itemCount--;
            });
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
