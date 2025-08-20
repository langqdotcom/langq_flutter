// GENERATED CODE - DO NOT MODIFY BY HAND
// *************************************************
// Auto-generated Dart file
// *************************************************

import 'package:langq_localization/langq.dart';

class LangQKey {
  /// Base: Apply
  static String commonApplybutton() {
    return LangQ.text('common.applyButton');
  }

  /// Base: Developer
  static String commonDeveloper() {
    return LangQ.text('common.developer');
  }

  /// Base: Example Demo
  static String exampleDemo() {
    return LangQ.text('exampleDemo');
  }

  /// Base: Hello World!
  static String helloWorld() {
    return LangQ.text('helloWorld');
  }

  /// Base: Hello {userFirst}
  static String helloMessage({required String userFirst}) {
    return LangQ.text('helloMessage', args: {'userFirst': userFirst});
  }

  /// Base: John
  static String commonJohn() {
    return LangQ.text('common.john');
  }

  /// Base: {appleCount, plural, one {There is {appleCount} apple} other {There are {appleCount} apples}} and {orangeCountValue, plural, one {{orangeCountValue} orange} other {{orangeCountValue} oranges}} on the table.
  static String tableFruitcount({
    required num appleCount,
    required num orangeCountValue,
  }) {
    return LangQ.text(
      'table.fruitCount',
      args: {
        'appleCount': '$appleCount',
        'orangeCountValue': '$orangeCountValue',
      },
    );
  }

  /// Base: {carsCount, plural, one {There is {carsCount} car} other {There are {carsCount} cars}} on {roadName}
  static String roadCarscount({
    required num carsCount,
    required String roadName,
  }) {
    return LangQ.text(
      'road.carsCount',
      args: {'carsCount': '$carsCount', 'roadName': roadName},
    );
  }
}
