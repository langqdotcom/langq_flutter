import 'package:example/l10n/generated/langq_locales.g.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';

class LocalePicker extends StatefulWidget {
  const LocalePicker({super.key});

  static show(context) async {
    var locale = await showModalBottomSheet<Locale>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      isDismissible: true,
      showDragHandle: true,
      builder: (context) {
        return LocalePicker();
      },
    );

    if (locale != null) {
      LangQ.setLocale(locale);
    }
  }

  @override
  State<LocalePicker> createState() => _LocalePickerState();
}

class _LocalePickerState extends State<LocalePicker> {
  Locale? selectedLocale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 400,
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(
                initialItem: LangQLocales.supportedLocales.indexOf(
                  LangQ.currentLocale,
                ),
              ),
              itemExtent: 50, // height of each item
              onSelectedItemChanged: (index) {
                selectedLocale = LangQLocales.supportedLocales[index];
              },
              children:
                  LangQLocales.supportedLocales.map((e) {
                    return Center(
                      child: Text(
                        e.toLanguageTag(),
                        style: TextStyle(fontSize: 25),
                      ),
                    );
                  }).toList(),
            ),
          ),

          MaterialButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            color: const Color.fromARGB(255, 109, 85, 114),
            padding: EdgeInsets.symmetric(horizontal: 60, vertical: 15),
            child: Text(
              'Apply',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              Navigator.pop(context, selectedLocale);
            },
          ),

          SizedBox(height: 50),
        ],
      ),
    );
  }
}
