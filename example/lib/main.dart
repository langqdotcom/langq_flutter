import 'package:example/l10n/generated/langq_locales.g.dart';
import 'package:example/locale_picker.dart';
import 'package:example/tabs/currency.dart';
import 'package:example/tabs/date.dart';
import 'package:example/tabs/multiple_placeholders.dart';
import 'package:example/tabs/nested_plural.dart';
import 'package:example/tabs/numbers.dart';
import 'package:example/tabs/placeholder.dart';
import 'package:example/tabs/plural.dart';
import 'package:example/tabs/simple_text.dart';
import 'package:example/tabs/time.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';
import 'package:example/l10n/generated/langq_key.g.dart';

class Orange {
  static Count count = Count();
}

class Count {
  int value = 0;
}

void main() async {
  await LangQ.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LangQ.builder(
      builder: (context, value) {
        return MaterialApp(
          localizationsDelegates: value.localizationsDelegates,
          locale: value.currentLocale,
          supportedLocales: LangQLocales.supportedLocales,
          title: LangQKey.mainExampledemo(),
          home: const Home(),
        );
      },
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  int itemCount = 0;
  int couponCount = 0;

  @override
  void initState() {
    super.initState();
  }

  // Hello World!
  List<String> user = [
    //
    LangQKey.commonNameJohn(),
    // @langq-ignore
    'David ',
  ];

  String account = LangQKey.developer();

  // final _tabs = [
  //   'Simple',
  //   'Placeholder',
  //   'Plural',
  //   'Multiple Placeholders',
  //   'Nested Plural',
  //   'Number',
  //   'Date',
  //   'Time',
  //   'Currency',
  //   'Percentage',
  // ];

  int carsCount = 0;
  String roadName = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Center(
            child: Text(
              LangQKey.mainTextCarsonroad(
                roadName: roadName,
                orangeCountValue: Orange.count.value,
              ),
            ),
          ),

          Center(child: Text(LangQKey.mainHelloqwerty())),
        ],
      ),
    );
    // return DefaultTabController(
    //   length: _tabs.length,
    //   child: Scaffold(
    //     appBar: AppBar(
    //       backgroundColor: Theme.of(context).colorScheme.inversePrimary,
    //       title: Text('Lang Q Demo'),
    //       actions: [
    //         Padding(
    //           padding: const EdgeInsets.symmetric(horizontal: 20.0),
    //           child: GestureDetector(
    //             onTap: () {
    //               LocalePicker.show(context);
    //             },
    //             child: Text(
    //               LangQ.currentLocale.toLanguageTag(),
    //               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    //             ),
    //           ),
    //         ),
    //       ],
    //       bottom: TabBar(
    //         tabs: _tabs.map((e) => Tab(text: e)).toList(),
    //         isScrollable: true,
    //       ),
    //     ),
    //     body: TabBarView(
    //       children: [
    //         SimpleText(),
    //         PlaceholderText(),
    //         Plural(),
    //         MultiplePlaceholders(),
    //         NestedPlural(),
    //         NumbersFormat(),
    //         DateFormat(),
    //         TimeFormat(),
    //         CurrencyFormat(),
    //         // PercentageFormat(),

    //         ),
    //       ],
    //     ),
    //   ),
    // );
  }
}

class FloatingCounter extends StatelessWidget {
  const FloatingCounter({
    required this.lable,
    required this.count,
    required this.onAdd,
    required this.onSub,

    super.key,
  });

  final String lable;
  final num count;
  final VoidCallback onAdd;
  final VoidCallback onSub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            lable,
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 20),
          ),
          Spacer(),
          FloatingActionButton(
            mini: true,
            onPressed: onSub,
            child: Icon(Icons.remove),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              count.toString(),
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),

          FloatingActionButton(
            mini: true,
            onPressed: onAdd,
            child: Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
