import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:langq_localization/src/extenstions.dart';
import 'package:langq_localization/src/langq_controller.dart';
import 'package:langq_localization/src/model.dart';

class Parser {
  static parse(String message, {Map<String, String>? args}) {
    message = message.escapeIcu();

    var placeholders = _extractPlaceholders(message);

    for (var e in placeholders) {
      if (args?[e] != null) {
        message = message.replaceAll('{$e}', args![e]!);
      }
    }

    var resolvedPlural = _resolvePlural(message, args);
    return resolvedPlural.unescapeIcu();
  }

  static String _resolvePlural(String message, Map<String, String>? args) {
    List<IcuBlock> icuBlocks = [];
    var statements = _extractTopLevelBraces(message);

    for (var statement in statements) {
      var splittedBlock = statement.split(',');
      if (splittedBlock.contains(' plural') && splittedBlock.length >= 2) {
        var argName = splittedBlock[0].trim();
        var type = splittedBlock[1].trim();
        var value = splittedBlock.sublist(2).join(',');
        var pluralBraces = _extractTopLevelBraces(value);

        icuBlocks.add(
          IcuBlock(
            statement: statement,
            type: type,
            argName: argName,
            value: Intl.plural(
              num.tryParse(args?[argName] ?? '') ?? -1,
              locale: LangQController.localeNotifier.value.languageCode,
              zero: pluralBraces.firstWhereOrNull(
                (e) => _containsMatchingOther('=0', statement, e),
              ),
              one: pluralBraces.firstWhereOrNull(
                (e) => _containsMatchingOther('one', statement, e),
              ),
              two: pluralBraces.firstWhereOrNull(
                (e) => _containsMatchingOther('two', statement, e),
              ),
              other:
                  pluralBraces.firstWhereOrNull(
                    (e) => _containsMatchingOther('other', statement, e),
                  ) ??
                  argName.encloseQuote(),
              few: pluralBraces.firstWhereOrNull(
                (e) => _containsMatchingOther('few', statement, e),
              ),
              many: pluralBraces.firstWhereOrNull(
                (e) => _containsMatchingOther('many', statement, e),
              ),
            ),
          ),
        );
      }
    }

    for (var e in icuBlocks) {
      var value = _checkAndResolvePlural(e.value, args);
      message = message.replaceAll('{${e.statement}}', value);
    }
    return message;
  }

  static String _checkAndResolvePlural(
    String message,
    Map<String, String>? args,
  ) {
    if (message.contains('plural')) {
      return _resolvePlural(message, args);
    }
    return message;
  }

  static List<String> _extractPlaceholders(String message) {
    final placeholders = <String>{};

    void extract(String str) {
      // Regex for ICU plural/select blocks: {varName, type, ...}
      final icuBlockReg = RegExp(r'\{(\w+),\s*(plural|select),');

      // Regex for simple placeholders like {label}
      final placeholderReg = RegExp(r'\{(\w+)\}');

      // Extract ICU block variables (like itemCount)
      for (final match in icuBlockReg.allMatches(str)) {
        placeholders.add(match.group(1)!);
      }

      // Extract simple placeholders (like label, anotherLabel)
      for (final match in placeholderReg.allMatches(str)) {
        placeholders.add(match.group(1)!);
      }

      // Remove escaped quotes and curly braces to avoid false positives
      String cleaned = str
          .replaceAll("''", '')
          .replaceAll("{{", '')
          .replaceAll("}}", '');

      // To avoid infinite recursion, remove already matched blocks and placeholders
      cleaned = cleaned.replaceAllMapped(icuBlockReg, (m) => '');
      cleaned = cleaned.replaceAllMapped(placeholderReg, (m) => '');
    }

    extract(message);
    return placeholders.toList();
  }

  static bool _containsMatchingOther(
    String key,
    String main,
    String placeholder,
  ) {
    var keyword = '$key{';
    int index = 0;

    while ((index = main.indexOf(keyword, index)) != -1) {
      index += keyword.length;
      final buffer = StringBuffer();
      int braceCount = 1;

      while (index < main.length) {
        final char = main[index];
        if (char == '}') {
          braceCount--;
          if (braceCount == 0) {
            break;
          }
        } else if (char == '{') {
          braceCount++;
        }
        buffer.write(char);
        index++;
      }

      final extracted = buffer.toString().trim();
      if (extracted == placeholder.trim()) {
        return true;
      }
    }

    return false;
  }

  static List<String> _extractTopLevelBraces(String input) {
    List<String> results = [];
    int braceDepth = 0;
    int? start;

    for (int i = 0; i < input.length; i++) {
      if (input[i] == '{') {
        if (braceDepth == 0) {
          start = i;
        }
        braceDepth++;
      } else if (input[i] == '}') {
        braceDepth--;
        if (braceDepth == 0 && start != null) {
          results.add(input.substring(start + 1, i));
          start = null;
        }
      }
    }

    return results;
  }
}
