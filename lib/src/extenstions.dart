import 'package:intl/intl.dart';
import 'package:langq_localization/src/langq.dart';

extension LocaleDateTime on DateTime {
  String dateFormat([bool numericformat = false]) {
    if (numericformat) {
      DateFormat dateFormat = DateFormat.yMd(LangQ.currentLocale.toString());
      return dateFormat.format(this);
    } else {
      DateFormat dateFormat = DateFormat.yMMMMd(LangQ.currentLocale.toString());
      return dateFormat.format(this);
    }
  }

  String timeFormat([bool withSeconds = false]) {
    final format =
        withSeconds
            ? DateFormat.jms(LangQ.currentLocale.toString())
            : DateFormat.jm(LangQ.currentLocale.toString());
    return format.format(this);
  }
}

extension LocaleNumber on num {
  String currencyFormat([bool compact = false]) {
    if (compact) {
      // Create a NumberFormat instance
      NumberFormat numberFormat = NumberFormat.compactSimpleCurrency(
        locale: LangQ.currentLocale.toString(),
      );
      return numberFormat.format(this);
    } else {
      NumberFormat currencyFormat = NumberFormat.simpleCurrency(
        locale: LangQ.currentLocale.toString(),
      );
      return currencyFormat.format(this);
    }
  }

  String numberFormat() {
    NumberFormat numberFormat = NumberFormat(
      "#,##0.00",
      LangQ.currentLocale.toString(),
    );
    return numberFormat.format(this);
  }

  String percentageFormat([int fractionDigits = 1]) {
    NumberFormat percentageFormat =
        NumberFormat.percentPattern(LangQ.currentLocale.toString())
          ..minimumFractionDigits = fractionDigits
          ..maximumFractionDigits = fractionDigits;
    return percentageFormat.format(this);
  }
}

extension Translate on String {
  String tr({Map<String, String>? args}) {
    return LangQ.text(this, args: args);
  }
}

extension IcuMessageEscape on String {
  String escapeIcu() {
    // Escape '' first
    var replaced = replaceAll("''", "__‹ESC_QUOTE›__");

    // Escape '{...}' if enclosed in single quotes
    replaced = replaced.replaceAllMapped(
      RegExp(r"'(\{[^}]+\})'"),
      (match) => match
          .group(1)!
          .replaceAll('{', '__‹ESC_OPEN›__')
          .replaceAll('}', '__‹ESC_CLOSE›__'),
    );

    return replaced;
  }

  String unescapeIcu() {
    return replaceAll(
      "__‹ESC_QUOTE›__",
      "'",
    ).replaceAll("__‹ESC_OPEN›__", "{").replaceAll("__‹ESC_CLOSE›__", "}");
  }

  String encloseQuote() {
    // Escape '' first
    var replaced = replaceAll("''", "__‹ESC_QUOTE›__");

    // Escape '{...}' if enclosed in single quotes
    replaced = replaced.replaceAllMapped(
      RegExp(r"'(\{[^}]+\})'"),
      (match) => match
          .group(1)!
          .replaceAll('{', '__‹ESC_OPEN›__')
          .replaceAll('}', '__‹ESC_CLOSE›__'),
    );

    return '__‹ESC_OPEN›__${this}__‹ESC_CLOSE›__';
  }
}
