import 'package:example_2/app_text.dart';
import 'package:example_2/l10n/generated/langq_key.g.dart';
import 'package:example_2/main.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';

class NestedPlural extends StatefulWidget {
  const NestedPlural({super.key});

  @override
  State<NestedPlural> createState() => _NestedPluralState();
}

class _NestedPluralState extends State<NestedPlural> {
  int usersCount = 0;
  int documentCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Apptext(
          LangQKey.messageDocumentview.tr(
            args: {
              'userCount': usersCount.toString(),
              'documentCount': documentCount.toString(),
            },
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingCounter(
            lable: 'Users',
            count: usersCount,
            onAdd: () {
              setState(() {
                usersCount++;
              });
            },
            onSub: () {
              if (usersCount > 0) {
                setState(() {
                  usersCount--;
                });
              }
            },
          ),

          SizedBox(height: 20),

          FloatingCounter(
            lable: 'Documents',
            count: documentCount,
            onAdd: () {
              setState(() {
                documentCount++;
              });
            },
            onSub: () {
              if (documentCount > 0) {
                setState(() {
                  documentCount--;
                });
              }
            },
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
