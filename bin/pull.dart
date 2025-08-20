import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'src/langq_pull.dart';
import 'src/utils.dart';
import 'src/api_key_service.dart';

void _printUsage() {
  stdout.write('Usage: langq <command> [arguments]\n');
  stdout.write('Available commands:\n');
  stdout.write('  dart run langq_localization:pull\n');
  stdout.write('  dart run langq_localization:pull --strings\n');
}

void main(List<String> arguments) async {
  try {
    var argParser =
        ArgParser()
          ..addFlag('strings', abbr: 's', negatable: false, defaultsTo: null)
          ..addOption('key', abbr: 'a', help: 'The API key');

    ArgResults argResults = argParser.parse(arguments);
    handlePull(argResults);
  } catch (e) {
    stdout.write('${CommandLineColor.red}❌ Error: $e\n');
    stdout.write('\r${CommandLineColor.white}');
  }
}

Future<void> handlePull(ArgResults argResults) async {
  if (argResults.arguments.isNotEmpty) {
    if (argResults['key'] == null && argResults['strings'] == null) {
      stdout.write('${CommandLineColor.red}Invalid Command\n');
      stdout.write('\r${CommandLineColor.white}');
      _printUsage();
      return;
    }
  }

  bool generateStrings = (argResults['strings'] as bool?) ?? false;
  String? apiKey = argResults['key'] ?? ApiKeyService.getApiKey();

  if (apiKey == null) {
    stdout.write('Please enter your API key: ');
    apiKey = stdin.readLineSync();
  }

  if (apiKey != null && apiKey.isNotEmpty) {
    LangQPull(apiKey: apiKey, canGenerateAsFucntion: !generateStrings);
  } else {
    stdout.write('No API key provided.');
  }
}
